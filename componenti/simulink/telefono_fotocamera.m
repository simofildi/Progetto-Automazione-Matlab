function [img, nuova, collegato] = telefono_fotocamera(H, W, passo)
%TELEFONO_FOTOCAMERA  Usata dal blocco "Fotocamera telefono". Non serve modificarla.
%   Aspetta la foto successiva del telefono (al massimo "passo" secondi) e la
%   restituisce ridimensionata a H x W pixel.

persistent ultima
if isempty(ultima) || ~isequal(size(ultima), [H W 3])
    ultima = zeros(H, W, 3, 'uint8');
end
tel = telefono_condiviso();
[foto, info] = tel.snapshot('Nuovo', true, 'Timeout', passo);
nuova = false;
if info.nuovo && ~isempty(foto)
    ultima = imresize(foto, [H W], 'bilinear', 'Antialiasing', false);
    nuova = true;
end
setappdata(0, 'Telefono_dimensioni', [H W]);
img = ultima;
collegato = info.collegato && info.eta_ms >= 0 && info.eta_ms < 2000;
end
