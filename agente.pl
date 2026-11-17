%% INF1771 - Trabalho 2 - Agente
%% Base de conhecimento, inferencia e escolha de acoes.
%% O agente nao consulta o mapa real: usa so percepcoes/1, posicao/3, energia/1 e map_size/2, alem da propria memoria.

%% Memoria do agente
:- dynamic visitei/2.
:- dynamic percep/3.         % percepcoes em cada casa
:- dynamic inimigo/2.
:- dynamic teleporte/2.
:- dynamic item/2.
:- dynamic ouros/1.
:- dynamic risco_acumulado/1.
:- dynamic estado_ant/4.     % posicao, direcao e energia no passo anterior

total_ouros(3).
orcamento_risco(1.0).

agente_reset :-
    retractall(visitei(_,_)), retractall(percep(_,_,_)),
    retractall(inimigo(_,_)), retractall(teleporte(_,_)),
    retractall(item(_,_)), retractall(ouros(_)), retractall(risco_acumulado(_)),
    retractall(estado_ant(_,_,_,_)),
    assertz(ouros(0)), assertz(risco_acumulado(0)).


%% 1. PERCEPCAO E MEMORIA
%% Chamado depois de cada acao.

agente_percebe(UltimaAcao) :-
    posicao(X,Y,D), D \== morto, !,
    energia(E),
    percepcoes(L),
    deduz_teleporte(UltimaAcao, X, Y),
    deduz_inimigo(X, Y, E),
    ( visitei(X,Y) -> true ; assertz(visitei(X,Y)) ),
    retractall(percep(X,Y,_)), assertz(percep(X,Y,L)),
    atualiza_item(X, Y, L),
    retractall(estado_ant(_,_,_,_)), assertz(estado_ant(X,Y,D,E)).
agente_percebe(_).

% andou e nao esta na casa da frente -> a casa da frente e teleporte
deduz_teleporte(andar, X, Y) :-
    estado_ant(X0,Y0,D,_),
    casa_frente(X0,Y0,D,FX,FY),
    \+ (FX == X, FY == Y), !,
    ( teleporte(FX,FY) -> true ; assertz(teleporte(FX,FY)) ).
deduz_teleporte(_, _, _).

% energia caiu -> inimigo na casa atual
deduz_inimigo(X, Y, E) :-
    estado_ant(_,_,_,E0), E < E0, !,
    ( inimigo(X,Y) -> true ; assertz(inimigo(X,Y)) ).
deduz_inimigo(_, _, _).

% guarda onde viu reflexo
atualiza_item(X, Y, L) :-
    (   memberchk(reflexo, L)
    ->  ( item(X,Y) -> true ; assertz(item(X,Y)) )
    ;   retractall(item(X,Y))
    ).


%% 2. REGRAS DE INFERENCIA

dentro(X,Y) :- map_size(MX,MY), X >= 1, X =< MX, Y >= 1, Y =< MY.

% vizinhas (sem diagonais)
adj(X,Y,A,Y) :- A is X + 1, dentro(A,Y).
adj(X,Y,A,Y) :- A is X - 1, dentro(A,Y).
adj(X,Y,X,B) :- B is Y + 1, dentro(X,B).
adj(X,Y,X,B) :- B is Y - 1, dentro(X,B).

casa_frente(X,Y,norte,X,B) :- B is Y + 1, dentro(X,B).
casa_frente(X,Y,sul,X,B)   :- B is Y - 1, dentro(X,B).
casa_frente(X,Y,leste,A,Y) :- A is X + 1, dentro(A,Y).
casa_frente(X,Y,oeste,A,Y) :- A is X - 1, dentro(A,Y).

% Perigo descartado: casa visitada, ou vizinha de casa visitada sem a percepcao correspondente. Cada casa tem no maximo um elemento.

sem_poco(X,Y) :- visitei(X,Y), !.
sem_poco(X,Y) :- teleporte(X,Y), !.
sem_poco(X,Y) :- inimigo(X,Y), !.
sem_poco(X,Y) :- adj(X,Y,A,B), percep(A,B,L), \+ memberchk(brisa,L), !.

sem_inimigo(X,Y) :- visitei(X,Y), \+ inimigo(X,Y), !.
sem_inimigo(X,Y) :- teleporte(X,Y), !.
sem_inimigo(X,Y) :- poco_certo(X,Y), !.
sem_inimigo(X,Y) :- adj(X,Y,A,B), percep(A,B,L), \+ memberchk(passos,L), !.

sem_teleporte(X,Y) :- visitei(X,Y), !.
sem_teleporte(X,Y) :- inimigo(X,Y), !.
sem_teleporte(X,Y) :- poco_certo(X,Y), !.
sem_teleporte(X,Y) :- adj(X,Y,A,B), percep(A,B,L), \+ memberchk(palmas,L), !.

seguro(X,Y) :- sem_poco(X,Y), sem_inimigo(X,Y), sem_teleporte(X,Y).

% Perigo certo por eliminacao: a vizinha (A,B) sentiu a percepcao e todas as outras vizinhas dela ja foram descartadas.
poco_certo(X,Y) :-
    \+ visitei(X,Y),
    adj(X,Y,A,B), percep(A,B,L), memberchk(brisa,L),
    \+ ( adj(A,B,C,D), \+ (C == X, D == Y), \+ sem_poco(C,D) ), !.

inimigo_certo(X,Y) :- inimigo(X,Y), !.
inimigo_certo(X,Y) :-
    \+ visitei(X,Y),
    adj(X,Y,A,B), percep(A,B,L), memberchk(passos,L),
    \+ ( adj(A,B,C,D), \+ (C == X, D == Y), \+ sem_inimigo(C,D) ), !.

teleporte_certo(X,Y) :- teleporte(X,Y), !.
teleporte_certo(X,Y) :-
    \+ visitei(X,Y),
    adj(X,Y,A,B), percep(A,B,L), memberchk(palmas,L),
    \+ ( adj(A,B,C,D), \+ (C == X, D == Y), \+ sem_teleporte(C,D) ), !.

% Perigo possivel (casas nao visitadas vizinhas de visitadas)
borda(X,Y) :-
    map_size(MX,MY), between(1,MX,X), between(1,MY,Y),
    \+ visitei(X,Y), once((adj(X,Y,A,B), visitei(A,B))).

possivel_poco(X,Y)      :- borda(X,Y), \+ sem_poco(X,Y).
possivel_inimigo(X,Y)   :- borda(X,Y), \+ sem_inimigo(X,Y).
possivel_teleporte(X,Y) :- borda(X,Y), \+ sem_teleporte(X,Y).

%% 3. PLANEJAMENTO (BFS sobre o mapa conhecido)

% bfs(+Inicio, +Objetivo, -Caminho): casas X-Y; só passa por casas seguras,
% mas a casa final pode ser de risco (apostas).

bfs(Inicio, Objetivo, Caminho) :-
    bfs_fila([[Inicio]], [Inicio], Inicio, Objetivo, Rev),
    reverse(Rev, [_|Caminho]).

bfs_fila([[C|R]|_], _, Inicio, Objetivo, [C|R]) :-
    C \== Inicio, call(Objetivo, C), !.
bfs_fila([[C|R]|Fila], Vistos, Inicio, Objetivo, Res) :-
    C = X-Y,
    (   ( C == Inicio ; seguro(X,Y) )
    ->  findall([NX-NY,C|R],
                ( adj(X,Y,NX,NY), \+ memberchk(NX-NY, Vistos),
                  ( seguro(NX,NY) ; call(Objetivo, NX-NY) ) ),
                Novos)
    ;   Novos = []
    ),
    findall(N, member([N|_], Novos), Ns),
    append(Vistos, Ns, Vistos2),
    append(Fila, Novos, Fila2),
    bfs_fila(Fila2, Vistos2, Inicio, Objetivo, Res).

alvo_fronteira(X-Y) :- \+ visitei(X,Y), seguro(X,Y).
alvo_casa(1-1).
alvo_item(X-Y)      :- item(X,Y).

alvo_aposta(X-Y)    :- limite_atual(Lim), borda(X,Y), risco(X,Y,R), R =< Lim.

%% 3b. AVALIACAO DE RISCO
%% Para cada vizinha visitada que sentiu perigo: se ela ja e explicada por um perigo certo, usa a probabilidade a priori; senao,
%% 1/K, onde K e o numero de candidatas. Fica o maior valor.

:- dynamic limite_atual/1.

% a priori: 8 pocos, 4 inimigos, 4 teleportes em 144 casas
a_priori(poco, 0.06).
a_priori(inimigo, 0.03).
a_priori(teleporte, 0.03).

percepcao_de(poco, brisa).
percepcao_de(inimigo, passos).
percepcao_de(teleporte, palmas).

descartado(poco, X, Y)      :- sem_poco(X,Y).
descartado(inimigo, X, Y)   :- sem_inimigo(X,Y).
descartado(teleporte, X, Y) :- sem_teleporte(X,Y).

certo(poco, X, Y)      :- poco_certo(X,Y).
certo(inimigo, X, Y)   :- inimigo_certo(X,Y).
certo(teleporte, X, Y) :- teleporte_certo(X,Y).

risco_de(Perigo, X, Y, 0) :- descartado(Perigo, X, Y), !.
risco_de(Perigo, X, Y, 1) :- certo(Perigo, X, Y), !.
risco_de(Perigo, X, Y, R) :-
    percepcao_de(Perigo, Perc),
    a_priori(Perigo, P0),
    findall(Rv,
            ( adj(X,Y,A,B), percep(A,B,L), memberchk(Perc, L),
              contribuicao(Perigo, X, Y, A, B, P0, Rv) ),
            Rs),
    max_list([P0|Rs], R).

contribuicao(Perigo, X, Y, A, B, P0, P0) :-
    adj(A,B,C,D), \+ (C == X, D == Y), certo(Perigo, C, D), !.
contribuicao(Perigo, _, _, A, B, _, R) :-
    findall(C-D, (adj(A,B,C,D), \+ descartado(Perigo,C,D)), Cands),
    length(Cands, K), K > 0, R is 1 / K.

% risco total: poco peso 1, inimigo 1 ou 0.2 (energia >= 90), teleporte 0.1
risco(X, Y, R) :-
    \+ inimigo(X,Y),
    risco_de(poco, X, Y, Rp),
    risco_de(inimigo, X, Y, Ri),
    risco_de(teleporte, X, Y, Rt),
    energia(E),
    ( E >= 90 -> Wi = 0.2 ; Wi = 1 ),
    R is Rp + Wi * Ri + 0.1 * Rt.

limite_risco(0.34).

% vai para a casa de menor risco que tenha caminho
aposta(A) :-
    limite_risco(Lim), orcamento_risco(Orc), risco_acumulado(Ac),
    Max is min(Lim, Orc - Ac),
    findall(R, (borda(X,Y), risco(X,Y,R), R =< Max), Rs0),
    sort(Rs0, Rs),
    member(R, Rs),
    retractall(limite_atual(_)), assertz(limite_atual(R)),
    vai_para(alvo_aposta, A), !.

%% 4. ESCOLHA DA ACAO (decide/1 em ordem de prioridade)

executa_acao(A) :- once(decide(A)), efeitos(A).

% (1) brilho: pega o ouro
decide(pegar) :- posicao(X,Y,_), percep(X,Y,L), memberchk(brilho,L).

% (2) na casa de um inimigo: foge
decide(A) :- posicao(X,Y,_), inimigo(X,Y), fuga(A).

% (3) reflexo e energia baixa: pega o item
decide(pegar) :- posicao(X,Y,_), percep(X,Y,L), memberchk(reflexo,L),
    energia(E), E =< 50.

% (4) pegou todos os ouros: volta e sai
decide(A) :- ouros(N), total_ouros(N), volta_para_casa(A).

% (5) energia baixa: vai ate um item conhecido
decide(A) :- energia(E), E =< 50, vai_para(alvo_item, A).

% (6) explora a casa segura mais proxima
decide(A) :- vai_para(alvo_fronteira, A).

% (7) arrisca a casa de menor risco
decide(A) :- aposta(A).

% (8) volta para [1,1] e sai
decide(A) :- volta_para_casa(A).

vai_para(Objetivo, A) :-
    posicao(X,Y,_), bfs(X-Y, Objetivo, Caminho), passo_para(Caminho, A).

volta_para_casa(sair) :- posicao(1,1,_), !.
volta_para_casa(A)    :- vai_para(alvo_casa, A), !.
volta_para_casa(sair).   % sem caminho até [1,1]

% primeiro passo do caminho -> andar ou virar
passo_para([NX-NY|_], A) :-
    posicao(X,Y,D),
    casa_frente(X,Y,ND,NX,NY), !,
    gira_ou_anda(D, ND, A).

gira_ou_anda(D, D, andar) :- !.
gira_ou_anda(D, ND, virar_direita)  :- giro_direita(D, ND), !.
gira_ou_anda(D, ND, virar_esquerda) :- giro_direita(ND, D), !.
gira_ou_anda(_, _, virar_direita).

giro_direita(norte, leste).
giro_direita(leste, sul).
giro_direita(sul, oeste).
giro_direita(oeste, norte).

% fuga: toda acao na casa do inimigo causa dano, entao escolhe a saida
% com menos giros (segura; senao, sem poco)
fuga(A) :-
    posicao(X,Y,D),
    member(Criterio, [seguro, sem_poco]),
    member(Giros-ND, [0-D, 1-R, 1-E, 2-O]),
    giro_direita(D,R), giro_direita(E,D), giro_direita(R,O),
    casa_frente(X,Y,ND,FX,FY),
    call(Criterio, FX, FY), !,
    ( Giros =:= 0 -> A = andar ; gira_ou_anda(D, ND, A) ).
fuga(andar) :- posicao(X,Y,D), casa_frente(X,Y,D,_,_), !.
fuga(virar_direita).

% atualiza contadores do agente
efeitos(pegar) :- posicao(X,Y,_), percep(X,Y,L), memberchk(brilho,L), !,
    ouros(N), retract(ouros(N)), N1 is N + 1, assertz(ouros(N1)).
efeitos(andar) :- posicao(X,Y,D), casa_frente(X,Y,D,FX,FY),
    \+ seguro(FX,FY), risco(FX,FY,R), !,
    risco_acumulado(Ac), retract(risco_acumulado(Ac)), Ac1 is Ac + R,
    assertz(risco_acumulado(Ac1)).
efeitos(_).

%% 5. CONSULTAS PARA A INTERFACE
%% kb_resumo(-L): [X, Y, Simbolo, Certeza]

kb_resumo(L) :-
    map_size(MX,MY),
    findall([X,Y,S,C],
            ( between(1,MX,X), between(1,MY,Y), kb_celula(X,Y,S,C) ),
            L).

kb_celula(X,Y,'P',1) :- poco_certo(X,Y).
kb_celula(X,Y,'P',0) :- \+ poco_certo(X,Y), possivel_poco(X,Y).
kb_celula(X,Y,'D',1) :- inimigo_certo(X,Y).
kb_celula(X,Y,'D',0) :- \+ inimigo_certo(X,Y), possivel_inimigo(X,Y).
kb_celula(X,Y,'T',1) :- teleporte_certo(X,Y).
kb_celula(X,Y,'T',0) :- \+ teleporte_certo(X,Y), possivel_teleporte(X,Y).
kb_celula(X,Y,'U',1) :- item(X,Y).
kb_celula(X,Y,'O',1) :- percep(X,Y,L), memberchk(brilho,L).

visitadas(L) :- findall([X,Y], visitei(X,Y), L).
