function [oggetti, numero] = riconoscitore_simulink(img, idParametri, soglia, N)
%RICONOSCITORE_SIMULINK  Usata dal blocco "Riconoscitore". Non serve modificarla.
%   oggetti : N x 6, una riga per oggetto [x y larghezza altezza punteggio classe]
%             (pixel dell'immagine in ingresso; righe di zeri se gli oggetti sono meno di N)
%   numero  : quanti oggetti sono stati trovati

persistent r chiave ultimaImg ultimoRisultato
par = parametri_blocco(idParametri);
nuovaChiave = string(par.Modello) + "#" + string(par.Etichette);
if isempty(r) || ~isvalid(r) || chiave ~= nuovaChiave
    r = Riconoscitore(string(par.Modello), Etichette = string(par.Etichette));
    chiave = nuovaChiave;
    ultimaImg = [];
end
r.Soglia = soglia;
r.MaxOggetti = N;
setappdata(0, 'Riconoscitore_attivo', r);

if isempty(ultimaImg) || ~isequal(img, ultimaImg)       % analizza solo le immagini nuove
    ogg = r.rileva(img);
    M = zeros(N, 6);
    n = min(height(ogg), N);
    M(1:n, :) = [ogg.Box(1:n, :), ogg.Punteggio(1:n), ogg.Classe(1:n)];
    ultimaImg = img;
    ultimoRisultato = M;
end
oggetti = ultimoRisultato;
numero = nnz(oggetti(:, 5) > 0);
end
