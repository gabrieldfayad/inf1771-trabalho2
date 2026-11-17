# Roda o agente sem interface N vezes em cada mapa e salva resultados.csv
# Uso: python testes.py 100
import csv, os, sys
from pyswip import Prolog

PASTA = os.path.dirname(os.path.abspath(__file__)).replace('\\', '/')
MAPAS = ['mapa_facil.pl', 'mapa_medio.pl', 'mapa_dificil.pl']
MAX_ACOES = 1000

prolog = Prolog()
prolog.consult(PASTA + '/main.pl')


def um(q):
    r = list(prolog.query(q, maxresult=1))
    return r[0] if r else None


def roda_episodio():
    um('reinicia')
    um('verifica_player, agente_percebe(nenhuma)')
    while True:
        st = um('posicao(_,_,D), num_acoes(N), (fim_de_jogo(F) -> true ; F = nao)')
        if st['D'] == 'morto':
            motivo = 'morreu'
            break
        if st['F'] != 'nao':
            motivo = str(st['F'])
            break
        if st['N'] >= MAX_ACOES:
            motivo = 'limite_acoes'
            break
        acao = um('executa_acao(A)')['A']
        um(acao)
        um('verifica_player, agente_percebe(%s)' % acao)
    r = um('pontuacao(P), ouro_coletado(O), num_acoes(N), energia(E), posicao(X,Y,_)')
    return {'pontuacao': r['P'], 'ouro': r['O'], 'acoes': r['N'], 'energia': r['E'],
            'sobreviveu': motivo != 'morreu', 'fim': motivo,
            'posicao_final': '%s,%s' % (r['X'], r['Y'])}


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    linhas = []
    for mapa in MAPAS:
        um("carrega_mapa('%s/%s')" % (PASTA, mapa))
        res = []
        for i in range(n):
            r = roda_episodio()
            r.update({'mapa': mapa, 'execucao': i + 1})
            res.append(r)
        linhas += res
        viv = sum(r['sobreviveu'] for r in res)
        print('%-16s execucoes=%d  pontuacao_media=%.1f  ouro_medio=%.2f  '
              'sobrevivencia=%d/%d  acoes_media=%.1f  saiu_em_1_1=%d' % (
                  mapa, n, sum(r['pontuacao'] for r in res) / n,
                  sum(r['ouro'] for r in res) / n, viv, n,
                  sum(r['acoes'] for r in res) / n,
                  sum(r['fim'] == 'saiu' for r in res)))
    with open(os.path.join(PASTA, 'resultados.csv'), 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['mapa', 'execucao', 'pontuacao', 'ouro', 'sobreviveu',
                                          'acoes', 'energia', 'fim', 'posicao_final'])
        w.writeheader()
        w.writerows(linhas)
    print('Resultados detalhados em resultados.csv')


if __name__ == '__main__':
    main()
