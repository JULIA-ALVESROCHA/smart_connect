#!/usr/bin/env python3
"""
SmartCity Connect - gera o dashboard (dashboard/index.html) a partir das visoes do esquema rel.

Pagina unica, sem dependencias externas (abre offline). Os dados ficam embutidos como JSON.
Le somente visoes agregadas: o mesmo acesso do perfil sc_gestor_relatorios.
Uso: python3 dashboard/gerar_dashboard.py   (variaveis PG* para a conexao)
"""
import json, os, subprocess
from datetime import datetime
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
CONSULTAS = {
    "kpi": "SELECT row_to_json(k) FROM rel.kpi_geral k",
    "vagas_area": "SELECT json_agg(r) FROM (SELECT area AS rotulo, vagas_abertas AS valor, salario_medio, posicoes FROM rel.r01_vagas_abertas_por_area) r",
    "empresas": "SELECT json_agg(r) FROM (SELECT posicao, empresa, porte, setor_cnae, contratacoes FROM rel.r02_empresas_que_mais_contratam WHERE posicao <= 10 ORDER BY posicao, empresa LIMIT 10) r",
    "setores": "SELECT json_agg(r) FROM (SELECT setor AS rotulo, contratacoes AS valor, empresas_ativas FROM rel.r02b_contratacoes_por_setor WHERE contratacoes > 0 LIMIT 10) r",
    "candidatos_empresa": "SELECT json_agg(r) FROM (SELECT empresa, vagas, candidatos_distintos, candidaturas, em_andamento FROM rel.r03_candidatos_por_empresa ORDER BY candidaturas DESC LIMIT 10) r",
    "beneficios": "SELECT json_agg(r) FROM (SELECT programa AS rotulo, ativos AS valor, esfera, valor_mensal_total, encerrados FROM rel.r04_beneficios_concedidos) r",
    "familias_programa": "SELECT json_agg(r) FROM (SELECT programa AS rotulo, familias_atendidas AS valor, renda_per_capita_media FROM rel.r05_familias_por_programa) r",
    "atend_regiao": "SELECT json_agg(r) FROM (SELECT regiao AS rotulo, atendimentos AS valor, pessoas_atendidas FROM rel.r06_atendimentos_por_regiao WHERE bairro IS NULL AND regiao IS NOT NULL AND ano = date_part('year', now()) ORDER BY atendimentos DESC) r",
    "territorio": "SELECT json_agg(r) FROM (SELECT * FROM rel.mv_painel_territorial ORDER BY pbf_por_mil_hab DESC) r",
    "contratados": "SELECT json_agg(r) FROM (SELECT programa, beneficiarios_ativos, no_cadastro_de_emprego, contratados, taxa_contratacao_pct FROM rel.r09_beneficiarios_contratados) r",
    "funil": "SELECT json_agg(r) FROM (SELECT etapa AS rotulo, candidaturas_que_passaram AS valor, dias_medios_desde_envio FROM rel.r12_funil_candidaturas WHERE ativa OR etapa = 'CONTRATADA' ORDER BY candidaturas_que_passaram DESC) r",
}


def consultar(sql):
    r = subprocess.run(["psql", "-X", "-q", "-t", "-A", "-c", sql], capture_output=True, text=True, env=os.environ)
    if r.returncode:
        raise SystemExit(r.stderr)
    return json.loads(r.stdout.strip() or "null")


HTML = r"""<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>SmartCity Connect | Painel de Nova Esperança Digital</title>
<style>
.viz-root{color-scheme:light;--surface-0:#f4f3f0;--surface-1:#fcfcfb;--text-primary:#0b0b0b;--text-secondary:#52514e;--text-muted:#7a7974;
 --grid:#e3e2de;--border:#dcdbd6;--series-1:#2a78d6;--seq-1:#e8f1fc;--seq-2:#b9d4f4;--seq-3:#7fb0ea;--seq-4:#3f86dc;--seq-5:#1e5aa8}
@media (prefers-color-scheme:dark){:root:where(:not([data-theme="light"])) .viz-root{color-scheme:dark;--surface-0:#111110;--surface-1:#1a1a19;
 --text-primary:#f0efec;--text-secondary:#c3c2b7;--text-muted:#8f8e86;--grid:#2c2c2a;--border:#33332f;--series-1:#3987e5;
 --seq-1:#1d2a3b;--seq-2:#1f3e66;--seq-3:#285b96;--seq-4:#3a7ccc;--seq-5:#79abeb}}
*{box-sizing:border-box}body{margin:0}
.viz-root{background:var(--surface-0);color:var(--text-primary);font:14px/1.45 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;min-height:100vh;padding:24px}
header{max-width:1240px;margin:0 auto 18px}h1{font-size:22px;margin:0 0 4px}header p{margin:0;color:var(--text-secondary)}
.wrap{max-width:1240px;margin:0 auto;display:grid;gap:16px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px}
.tile{background:var(--surface-1);border:1px solid var(--border);border-radius:10px;padding:12px 14px}
.tile .v{font-size:24px;font-weight:650;font-variant-numeric:tabular-nums}.tile .l{color:var(--text-secondary);font-size:12.5px}
.mod{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--text-muted);font-weight:600}
.grid2{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:16px}
.card{background:var(--surface-1);border:1px solid var(--border);border-radius:10px;padding:16px;min-width:0}
.card h2{font-size:15px;margin:2px 0 2px}.card .sub{color:var(--text-secondary);font-size:12.5px;margin:0 0 10px}
.bar-row{display:grid;grid-template-columns:minmax(120px,38%) 1fr 72px;align-items:center;gap:10px;padding:3px 0;position:relative}
.bar-row .lab{color:var(--text-secondary);font-size:12.5px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.bar-row .track{height:14px;position:relative}
.bar-row .fill{height:14px;background:var(--series-1);border-radius:0 4px 4px 0;min-width:2px}
.bar-row .num{text-align:right;font-variant-numeric:tabular-nums;font-size:12.5px}
.bar-row:hover .lab,.bar-row:focus .lab{color:var(--text-primary)}.bar-row:hover .fill{filter:brightness(1.1)}
.bar-row:focus{outline:2px solid var(--series-1);outline-offset:2px;border-radius:4px}
table{width:100%;border-collapse:collapse;font-size:12.5px;font-variant-numeric:tabular-nums}
th,td{padding:5px 8px;border-bottom:1px solid var(--grid);text-align:right;white-space:nowrap}
th:first-child,td:first-child,#t_terr th:nth-child(2),#t_terr td:nth-child(2){text-align:left}th{color:var(--text-secondary);font-weight:600}
td.heat{color:var(--text-primary)}
.scroll{overflow-x:auto}
details{margin-top:8px}summary{cursor:pointer;color:var(--text-secondary);font-size:12.5px}
#tip{position:fixed;pointer-events:none;background:var(--surface-1);color:var(--text-primary);border:1px solid var(--border);
 border-radius:8px;padding:8px 10px;font-size:12.5px;box-shadow:0 4px 16px rgba(0,0,0,.16);display:none;max-width:320px;z-index:9}
#tip b{display:block;margin-bottom:2px}
.legend{display:flex;gap:6px;align-items:center;color:var(--text-secondary);font-size:12px;margin-top:8px}
.legend i{display:inline-block;width:22px;height:10px;border-radius:2px}
footer{max-width:1240px;margin:18px auto 0;color:var(--text-muted);font-size:12px}
</style></head>
<body><div class="viz-root">
<header><h1>SmartCity Connect · Nova Esperança Digital</h1>
<p>Painel integrado dos módulos Cidadãos, Educação, Emprego e Assistência Social. Dados de __GERADO__.</p></header>
<div class="wrap">
<section class="kpis" id="kpis" aria-label="Indicadores gerais"></section>
<div class="grid2">
 <div class="card"><div class="mod">Emprego</div><h2>Vagas abertas por área</h2><p class="sub">Exemplo do professor. Passe o mouse para ver salário médio.</p><div id="c_vagas"></div></div>
 <div class="card"><div class="mod">Emprego</div><h2>Empresas que mais contratam</h2><p class="sub">Exemplo do professor. Top 10 por contratações.</p><div id="c_emp"></div></div>
 <div class="card"><div class="mod">Emprego</div><h2>Candidatos por empresa</h2><p class="sub">Exemplo do professor. Top 10 por número de candidaturas.</p><div id="t_cand" class="scroll"></div></div>
 <div class="card"><div class="mod">Emprego</div><h2>Funil do processo seletivo</h2><p class="sub">Candidaturas que passaram por cada etapa (histórico de status).</p><div id="c_funil"></div></div>
 <div class="card"><div class="mod">Assistência Social</div><h2>Benefícios concedidos</h2><p class="sub">Exemplo do professor. Benefícios ativos por programa.</p><div id="c_ben"></div></div>
 <div class="card"><div class="mod">Assistência Social</div><h2>Famílias atendidas por programa</h2><p class="sub">Exemplo do professor. Passe o mouse para a renda per capita média.</p><div id="c_fam"></div></div>
 <div class="card"><div class="mod">Assistência Social</div><h2>Atendimentos por região</h2><p class="sub">Exemplo do professor. Ano corrente, pelo endereço vigente do cidadão.</p><div id="c_reg"></div></div>
 <div class="card"><div class="mod">Integração Assistência × Emprego</div><h2>Beneficiários que conseguiram emprego</h2><p class="sub">Só é possível porque os dois módulos apontam para o mesmo cidadão.</p><div id="t_contr" class="scroll"></div></div>
</div>
<div class="card"><div class="mod">Integração dos 4 módulos</div><h2>Painel territorial por bairro</h2>
<p class="sub">Uma linha por bairro, cruzando CID, EDU, EMP e ASS. A cor da coluna "PBF por mil hab." vai do claro (menor) ao escuro (maior).</p>
<div id="t_terr" class="scroll"></div>
<div class="legend">menor <i style="background:var(--seq-1)"></i><i style="background:var(--seq-2)"></i><i style="background:var(--seq-3)"></i><i style="background:var(--seq-4)"></i><i style="background:var(--seq-5)"></i> maior</div></div>
</div>
<footer>Dados sintéticos de uma cidade fictícia, com tabelas de referência públicas (IBGE, CNAE 2.3, CBO 2002). Gerado por dashboard/gerar_dashboard.py.</footer>
<div id="tip" role="tooltip"></div>
</div>
<script>
const D = __DADOS__;
const nf = new Intl.NumberFormat('pt-BR'), brl = new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL',maximumFractionDigits:0});
const tip = document.getElementById('tip');
function showTip(e, html){ tip.innerHTML = html; tip.style.display='block';
  const r = (e.target.closest('.bar-row')||e.target).getBoundingClientRect(); const x = e.clientX ?? r.right, y = e.clientY ?? r.top;
  tip.style.left = Math.min(window.innerWidth - tip.offsetWidth - 8, x + 14) + 'px'; tip.style.top = Math.max(8, y - tip.offsetHeight - 10) + 'px'; }
function hideTip(){ tip.style.display='none'; }
const CURTO = s => String(s).replace('Benefício de Prestação Continuada - Pessoa com Deficiência','BPC Pessoa com Deficiência').replace('Benefício de Prestação Continuada - Pessoa Idosa','BPC Pessoa Idosa');
const ETAPA = {ENVIADA:'Enviada',EM_ANALISE:'Em análise',ENTREVISTA:'Entrevista',APROVADA:'Aprovada',CONTRATADA:'Contratada'};
function esc(s){ return String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])); }
function bars(id, rows, fmtTip, fmtVal = v => nf.format(v)){
  const el = document.getElementById(id); const max = Math.max(...rows.map(r => +r.valor));
  el.innerHTML = rows.map((r,i) => `<div class="bar-row" tabindex="0" data-i="${i}"><span class="lab" title="${esc(r.rotulo)}">${esc(r.rotulo)}</span>
    <span class="track"><span class="fill" style="display:block;width:${(100*r.valor/max).toFixed(1)}%"></span></span><span class="num">${fmtVal(r.valor)}</span></div>`).join('')
    + `<details><summary>Ver tabela</summary>${table(rows.map(r => ({...r})), null)}</details>`;
  el.querySelectorAll('.bar-row').forEach(row => { const r = rows[row.dataset.i]; const h = `<b>${esc(r.rotulo)}</b>${fmtTip(r)}`;
    row.addEventListener('mousemove', e => showTip(e, h)); row.addEventListener('mouseleave', hideTip);
    row.addEventListener('focus', e => showTip(e, h)); row.addEventListener('blur', hideTip); });
}
const NOMES = {rotulo:'Item', valor:'Valor', salario_medio:'Salário médio', posicoes:'Posições', posicao:'#', empresa:'Empresa', porte:'Porte', setor_cnae:'Setor (CNAE)',
  contratacoes:'Contratações', vagas:'Vagas', candidatos_distintos:'Candidatos', candidaturas:'Candidaturas', em_andamento:'Em andamento',
  esfera:'Esfera', valor_mensal_total:'R$ mensal', encerrados:'Encerrados', renda_per_capita_media:'Renda per capita média', pessoas_atendidas:'Pessoas',
  programa:'Programa', beneficiarios_ativos:'Beneficiários', no_cadastro_de_emprego:'Buscam emprego', contratados:'Contratados', taxa_contratacao_pct:'Taxa (%)',
  regiao:'Região', bairro:'Bairro', habitantes:'Habitantes', beneficiarios:'Beneficiários', pbf_por_mil_hab:'PBF por mil hab.', alunos_rede_municipal:'Alunos',
  candidatos_emprego:'Candidatos', vagas_abertas_no_bairro:'Vagas abertas', dias_medios_desde_envio:'Dias desde o envio', empresas_ativas:'Empresas ativas'};
function cell(k, v){ if (v === null || v === undefined) return '–'; if (typeof v === 'number') return k.includes('valor_mensal') ? brl.format(v) : nf.format(v); return esc(v); }
function table(rows, heatCol){
  const cols = Object.keys(rows[0]); let lo = 0, hi = 1;
  if (heatCol){ const vs = rows.map(r => +r[heatCol]); lo = Math.min(...vs); hi = Math.max(...vs); }
  return `<table><thead><tr>${cols.map(c => `<th>${NOMES[c]||c}</th>`).join('')}</tr></thead><tbody>${rows.map(r => `<tr>${cols.map(c => {
    if (c === heatCol){ const s = 1 + Math.min(4, Math.floor(5 * (r[c]-lo) / ((hi-lo)||1))); const dark = s >= 4;
      return `<td class="heat" style="background:var(--seq-${s});${dark?'color:#fff':''}">${cell(c, r[c])}</td>`; }
    return `<td>${cell(c, r[c])}</td>`; }).join('')}</tr>`).join('')}</tbody></table>`;
}
// KPIs
const K = D.kpi; const tiles = [['Cidadãos','Cadastro',K.cidadaos],['Escolas','Educação',K.escolas],['Alunos ativos','Educação',K.alunos_ativos],
 ['Empresas ativas','Emprego',K.empresas_ativas],['Vagas abertas','Emprego',K.vagas_abertas],['Contratações','Emprego',K.contratacoes],
 ['Famílias assistidas','Assistência',K.familias_assistidas],['Benefícios ativos','Assistência',K.beneficios_ativos],
 ['Repasse mensal (R$)','Assistência',(K.valor_mensal_beneficios/1e6).toLocaleString('pt-BR',{maximumFractionDigits:1})+' mi'],['Atendimentos no ano','Assistência',K.atendimentos_no_ano]];
document.getElementById('kpis').innerHTML = tiles.map(t => `<div class="tile"><div class="mod">${t[1]}</div><div class="v">${typeof t[2]==='number'?nf.format(t[2]):t[2]}</div><div class="l">${t[0]}</div></div>`).join('');
bars('c_vagas', D.vagas_area, r => `${nf.format(r.valor)} vagas · ${nf.format(r.posicoes)} posições<br>Salário médio ${brl.format(r.salario_medio)}`);
bars('c_emp', D.empresas.map(r => ({rotulo: r.empresa, valor: r.contratacoes, porte: r.porte, setor_cnae: r.setor_cnae})), r => `${nf.format(r.valor)} contratações<br>${esc(r.porte)} · ${esc(r.setor_cnae)}`);
document.getElementById('t_cand').innerHTML = table(D.candidatos_empresa);
bars('c_funil', D.funil.map(r => ({...r, rotulo: ETAPA[r.rotulo] || r.rotulo})), r => `${nf.format(r.valor)} candidaturas${r.dias_medios_desde_envio ? `<br>${r.dias_medios_desde_envio} dias, em média, após o envio` : ''}`);
bars('c_ben', D.beneficios.map(r => ({...r, rotulo: CURTO(r.rotulo)})), r => `${nf.format(r.valor)} ativos · ${nf.format(r.encerrados)} encerrados<br>${brl.format(r.valor_mensal_total||0)} por mês · ${r.esfera.toLowerCase()}`);
bars('c_fam', D.familias_programa.map(r => ({...r, rotulo: CURTO(r.rotulo)})), r => `${nf.format(r.valor)} famílias<br>Renda per capita média ${brl.format(r.renda_per_capita_media)}`);
bars('c_reg', D.atend_regiao, r => `${nf.format(r.valor)} atendimentos<br>${nf.format(r.pessoas_atendidas)} pessoas atendidas`);
document.getElementById('t_contr').innerHTML = table(D.contratados.map(r => ({programa: CURTO(r.programa), beneficiarios_ativos: r.beneficiarios_ativos, no_cadastro_de_emprego: r.no_cadastro_de_emprego, contratados: r.contratados, taxa_contratacao_pct: r.taxa_contratacao_pct})));
document.getElementById('t_terr').innerHTML = table(D.territorio, 'pbf_por_mil_hab');
</script></body></html>"""


def main():
    psql_ok = subprocess.run(["psql", "-X", "-q", "-c", "REFRESH MATERIALIZED VIEW CONCURRENTLY rel.mv_painel_territorial"],
                             capture_output=True, env=os.environ)
    dados = {k: consultar(q) for k, q in CONSULTAS.items()}
    html = HTML.replace("__DADOS__", json.dumps(dados, ensure_ascii=False, default=str)) \
               .replace("__GERADO__", datetime.now().strftime("%d/%m/%Y %H:%M"))
    destino = RAIZ / "dashboard" / "index.html"
    destino.write_text(html, encoding="utf-8")
    print(f"  dashboard gerado: {destino.relative_to(RAIZ)} ({len(html) // 1024} kB)")


if __name__ == "__main__":
    main()
