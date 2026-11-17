%% INF1771 - Trabalho 2 - Ambiente
%% Simulador do mundo, adaptado do main.pl original. E o unico arquivo que usa o mapa real (tile/3).

:- dynamic tile/3.
:- dynamic map_size/2.
:- dynamic mapa_atual/1.
:- dynamic posicao/3.
:- dynamic energia/1.
:- dynamic pontuacao/1.
:- dynamic num_acoes/1.
:- dynamic ouro_coletado/1.
:- dynamic fim_de_jogo/1.

%% Carregamento do mapa

% carrega_mapa(+Arquivo): le tile/3 e map_size/2 do arquivo e reinicia o jogo
carrega_mapa(Arquivo) :-
    retractall(tile(_,_,_)),
    retractall(map_size(_,_)),
    retractall(mapa_atual(_)),
    open(Arquivo, read, S),
    le_termos(S),
    close(S),
    assertz(mapa_atual(Arquivo)),
    reset_game.

le_termos(S) :-
    read_term(S, T, []),
    (   T == end_of_file
    ->  true
    ;   guarda_termo(T), le_termos(S)
    ).

guarda_termo(tile(X,Y,Z)) :- !, assertz(tile(X,Y,Z)).
guarda_termo(map_size(X,Y)) :- !, assertz(map_size(X,Y)).
guarda_termo(_).

% recarrega o mapa atual
reinicia :- mapa_atual(A), carrega_mapa(A).

reset_game :-
    retractall(energia(_)),
    retractall(pontuacao(_)),
    retractall(posicao(_,_,_)),
    retractall(num_acoes(_)),
    retractall(ouro_coletado(_)),
    retractall(fim_de_jogo(_)),
    assertz(energia(100)),
    assertz(pontuacao(0)),
    assertz(posicao(1,1,norte)),
    assertz(num_acoes(0)),
    assertz(ouro_coletado(0)),
    agente_reset.

%% Controle de status

atualiza_pontuacao(X) :-
    pontuacao(P), retract(pontuacao(P)), NP is P + X, assertz(pontuacao(NP)), !.

conta_acao :-
    num_acoes(N), retract(num_acoes(N)), N1 is N + 1, assertz(num_acoes(N1)), !.

atualiza_energia(N) :-
    energia(E), retract(energia(E)), NE is E + N,
    (   NE =< 0
    ->  assertz(energia(0)),
        posicao(X,Y,_), retract(posicao(_,_,_)), assertz(posicao(X,Y,morto))
    ;   NE > 100
    ->  assertz(energia(100))
    ;   assertz(energia(NE))
    ), !.

% efeito da casa atual (chamado depois de toda acao)
verifica_player :- posicao(_,_,morto), !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'P'),
    atualiza_energia(-100), atualiza_pontuacao(-1000), !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'D'),
    random_between(-80,-50,D), atualiza_energia(D), !.
verifica_player :- posicao(X,Y,_), tile(X,Y,'d'),
    random_between(-50,-25,D), atualiza_energia(D), !.
verifica_player :- posicao(X,Y,Z), tile(X,Y,'T'),
    map_size(SX,SY), random_between(1,SX,NX), random_between(1,SY,NY),
    retract(posicao(X,Y,Z)), assertz(posicao(NX,NY,Z)),
    verifica_player, !.
verifica_player.

%% Acoes

virar_direita :- posicao(X,Y,D), D \== morto, direita(D,ND),
    retract(posicao(_,_,_)), assertz(posicao(X,Y,ND)),
    atualiza_pontuacao(-1), conta_acao, !.

virar_esquerda :- posicao(X,Y,D), D \== morto, direita(ND,D),
    retract(posicao(_,_,_)), assertz(posicao(X,Y,ND)),
    atualiza_pontuacao(-1), conta_acao, !.

% andar falha no limite do mapa
andar :- posicao(X,Y,D), D \== morto, frente(X,Y,D,NX,NY),
    map_size(MX,MY), NX >= 1, NX =< MX, NY >= 1, NY =< MY,
    retract(posicao(_,_,_)), assertz(posicao(NX,NY,D)),
    atualiza_pontuacao(-1), conta_acao, !.

pegar :- posicao(X,Y,_), tile(X,Y,'O'), !,
    retract(tile(X,Y,'O')), assertz(tile(X,Y,'')),
    atualiza_pontuacao(-5), atualiza_pontuacao(500), conta_acao,
    ouro_coletado(N), retract(ouro_coletado(N)), N1 is N + 1,
    assertz(ouro_coletado(N1)).
pegar :- posicao(X,Y,_), tile(X,Y,'U'), !,
    retract(tile(X,Y,'U')), assertz(tile(X,Y,'')),
    atualiza_pontuacao(-5), atualiza_energia(50), conta_acao.
pegar :- atualiza_pontuacao(-5), conta_acao.

% sair: encerra a partida (em [1,1] = saiu; fora = parou)
sair :- fim_de_jogo(_), !.
sair :- posicao(1,1,_), !, assertz(fim_de_jogo(saiu)).
sair :- assertz(fim_de_jogo(parou)).

direita(norte, leste).
direita(leste, sul).
direita(sul, oeste).
direita(oeste, norte).

frente(X,Y,norte,X,NY) :- NY is Y + 1.
frente(X,Y,sul,X,NY)   :- NY is Y - 1.
frente(X,Y,leste,NX,Y) :- NX is X + 1.
frente(X,Y,oeste,NX,Y) :- NX is X - 1.

%% Sensores

vizinho_real(X,Y,NX,NY) :-
    map_size(MX,MY),
    member(DX/DY, [1/0, -1/0, 0/1, 0/(-1)]),
    NX is X + DX, NY is Y + DY,
    NX >= 1, NX =< MX, NY >= 1, NY =< MY.

sente(X,Y,brisa)   :- once((vizinho_real(X,Y,A,B), tile(A,B,'P'))).
sente(X,Y,passos)  :- once((vizinho_real(X,Y,A,B), (tile(A,B,'D') ; tile(A,B,'d')))).
sente(X,Y,palmas)  :- once((vizinho_real(X,Y,A,B), tile(A,B,'T'))).
sente(X,Y,brilho)  :- tile(X,Y,'O').
sente(X,Y,reflexo) :- tile(X,Y,'U').

% percepcoes(-L): o que o agente sente na posicao atual
percepcoes(L) :-
    posicao(X,Y,_),
    findall(P, (member(P,[brisa,passos,palmas,brilho,reflexo]), sente(X,Y,P)), L).

%% Mapa real no terminal

show_map :-
    map_size(MX,MY),
    forall(between(1,MY,I),
           ( Y is MY - I + 1,
             forall(between(1,MX,X),
                    ( ( posicao(X,Y,_) -> write('@') ; write(' ') ),
                      tile(X,Y,Z), ( Z == '' -> write(' ') ; write(Z) ),
                      write('|') )),
             write(Y), nl )),
    energia(E), pontuacao(P),
    format('E: ~w   P: ~w~n', [E,P]).
