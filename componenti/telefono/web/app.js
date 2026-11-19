/* MATLAB Cam — web app del telefono.
 * Invia immagini JPEG al "ponte" che gira dentro MATLAB e mostra il risultato
 * dell'analisi che MATLAB rimanda indietro (titolo, colore, voci, riquadri).
 * Due modalita': Video (invio continuo) e Foto (uno scatto alla volta).
 */
"use strict";

const $ = (id) => document.getElementById(id);
const stato = {
  codice: "",
  id: idDispositivo(),
  pc: "",
  modo: "video",       // "video" | "foto"
  ciclo: 0,            // numero del ciclo di invio attivo (per fermare quelli vecchi)
  pausa: false,
  congelata: false,    // modalita' Foto: e' mostrata la foto scattata
  inAttesa: false,     // modalita' Foto: foto inviata, si aspetta MATLAB
  facing: "environment",
  stream: null,
  qualita: 2,          // indice in QUALITA
  versione: -1,
  errori: 0,
  rtt: 0,
  fps: 0,
  ultimoInvio: 0,
  ultimoRisultato: null,
  wakeLock: null,
};
const QUALITA = [               // lato massimo dell'immagine inviata e qualita' JPEG
  { lato: 320, q: 0.6, nome: "320" },
  { lato: 480, q: 0.65, nome: "480" },
  { lato: 640, q: 0.7, nome: "640" },
];
const FPS_MAX = 15;     // foto al secondo al massimo (con l'hotspot del telefono la rete non e' condivisa)
const puoVideo = () => window.isSecureContext && !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);

// ------------------------------------------------------------------ avvio
window.addEventListener("load", () => {
  const p = new URLSearchParams(location.search);
  stato.codice = (p.get("c") || "").toUpperCase();
  $("form-codice").addEventListener("submit", (e) => {
    e.preventDefault();
    stato.codice = $("campo-codice").value.trim().toUpperCase();
    history.replaceState(null, "", "?c=" + stato.codice);
    accoppia();
  });
  $("avvia-camera").addEventListener("click", apriFotocamera);
  $("btn-centrale").addEventListener("click", premiCentrale);
  $("btn-gira").addEventListener("click", giraCamera);
  $("btn-qualita").addEventListener("click", cambiaQualita);
  $("btn-esci").addEventListener("click", scollega);
  $("input-foto").addEventListener("change", fotoScelta);
  document.querySelectorAll("#modo button").forEach((b) =>
    b.addEventListener("click", () => impostaModo(b.dataset.modo)));
  window.addEventListener("resize", () => disegnaRisultato(stato.ultimoRisultato));
  window.addEventListener("pagehide", () => {
    try { navigator.sendBeacon(api("ciao_fine")); } catch (e) { /* niente */ }
  });
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible" && stato.stream) richiediWakeLock();
  });

  if (!puoVideo()) $("nota-https").classList.remove("nascosto");
  if (stato.codice) accoppia(); else mostraFormCodice();
});

function idDispositivo() {
  let id = null;
  try { id = localStorage.getItem("matlabcam-id"); } catch (e) { /* storage non disponibile */ }
  if (!id) {
    id = Math.random().toString(36).slice(2, 10);
    try { localStorage.setItem("matlabcam-id", id); } catch (e) { /* ok */ }
  }
  return id;
}

function api(cosa) {
  return `/api/${cosa}?c=${encodeURIComponent(stato.codice)}&id=${stato.id}`;
}

function descrizioneTelefono() {
  const ua = navigator.userAgent;
  let s = /iPhone/.test(ua) ? "iPhone" : /iPad/.test(ua) ? "iPad" : /Android/.test(ua) ? "Android" : "Browser";
  const m = ua.match(/Android [\d.]+; ([^;)]+)/);
  if (m && !/K$/.test(m[1])) s = m[1].trim();
  const b = /CriOS|Chrome/.test(ua) ? "Chrome" : /Safari/.test(ua) ? "Safari" : /Firefox/.test(ua) ? "Firefox" : "";
  return b ? `${s} · ${b}` : s;
}

const vibra = (ms) => { try { if (navigator.vibrate) navigator.vibrate(ms); } catch (e) { /* ok */ } };
const attesa = (ms) => new Promise((ok) => setTimeout(ok, ms));

// ------------------------------------------------------------------ collegamento
function mostraFormCodice() {
  $("box-stato").classList.add("nascosto");
  $("form-codice").classList.remove("nascosto");
  $("campo-codice").focus();
}

function impostaStato(testo, dettaglio, errore) {
  $("box-stato").classList.remove("nascosto");
  $("testo-stato").textContent = testo;
  $("dettaglio-stato").textContent = dettaglio || "";
  $("spinner").classList.toggle("errore", !!errore);
}

async function accoppia() {
  $("form-codice").classList.add("nascosto");
  $("box-collegato").classList.add("nascosto");
  impostaStato("Collegamento al PC…", "Codice " + stato.codice);
  try {
    const r = await fetch(api("ciao"), {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ descrizione: descrizioneTelefono() }),
    });
    const j = await r.json();
    if (!r.ok) {
      impostaStato(j.errore === "occupato" ? "PC già occupato" : "Codice non valido", j.messaggio || "", true);
      if (j.errore !== "occupato") setTimeout(mostraFormCodice, 1200);
      return;
    }
    stato.pc = j.pc;
    $("nome-pc").textContent = j.pc;
    $("box-stato").classList.add("nascosto");
    $("box-collegato").classList.remove("nascosto");
    vibra(30);
  } catch (e) {
    impostaStato("Non raggiungo il PC",
      "Controlla che MATLAB sia avviato e che telefono e PC siano sulla stessa rete (vedi Aiuto).", true);
    setTimeout(accoppia, 3000);
  }
}

// ------------------------------------------------------------------ fotocamera
async function apriFotocamera() {
  let modo = "foto";
  if (puoVideo()) {
    try { await apriStream(); modo = "video"; } catch (e) { stato.stream = null; }
  }
  $("modo").querySelector('[data-modo="video"]').disabled = !stato.stream;
  mostraSchermo("schermo-camera");
  if (stato.stream) richiediWakeLock();
  impostaModo(modo);
}

async function apriStream() {
  if (stato.stream) stato.stream.getTracks().forEach((t) => t.stop());
  const s = await navigator.mediaDevices.getUserMedia({
    audio: false,
    // niente vincoli di risoluzione: alcuni browser ritagliano l'immagine per rispettarli
    video: { facingMode: { ideal: stato.facing } },
  });
  stato.stream = s;
  const v = $("video");
  v.srcObject = s;
  v.style.transform = stato.facing === "user" ? "scaleX(-1)" : "";
  await v.play();
}

async function giraCamera() {
  if (!stato.stream) return;
  stato.facing = stato.facing === "environment" ? "user" : "environment";
  try { await apriStream(); } catch (e) { /* resta la camera attuale */ }
  if (stato.modo === "foto") scongela();
}

function cambiaQualita() {
  stato.qualita = (stato.qualita + 1) % QUALITA.length;
  $("btn-qualita").textContent = QUALITA[stato.qualita].nome;
}

async function richiediWakeLock() {
  try { if ("wakeLock" in navigator) stato.wakeLock = await navigator.wakeLock.request("screen"); } catch (e) { /* ok */ }
}

/** Video | Foto */
function impostaModo(modo) {
  if (modo === "video" && !stato.stream) return;
  stato.modo = modo;
  stato.ciclo++;                                   // ferma il ciclo di invio in corso
  const seg = $("modo");
  seg.classList.toggle("foto", modo === "foto");
  seg.querySelectorAll("button").forEach((b) => b.classList.toggle("attivo", b.dataset.modo === modo));
  scongela();
  $("btn-gira").style.visibility = stato.stream ? "visible" : "hidden";
  if (modo === "video") {
    stato.pausa = false;
    cicloInvio(stato.ciclo);
  } else {
    $("video").classList.toggle("nascosto", !stato.stream);
    mostraMessaggio("Scatta una foto", "MATLAB la analizza e qui compare il risultato.");
    battito();
  }
  aggiornaCentrale();
  vibra(10);
}

/** Il pulsante centrale: pausa/riprendi (Video), scatta o nuova foto (Foto). */
function premiCentrale() {
  if (stato.modo === "video") {
    stato.pausa = !stato.pausa;
    if (stato.pausa) $("pillola-info").textContent = "in pausa";
  } else if (stato.inAttesa) {
    return;
  } else if (stato.congelata) {
    scongela();
    mostraMessaggio("Scatta una foto", "MATLAB la analizza e qui compare il risultato.");
  } else if (stato.stream) {
    scattaDalVideo();
  } else {
    $("input-foto").click();                       // senza HTTPS: l'app Fotocamera del telefono
  }
  aggiornaCentrale();
  vibra(15);
}

function aggiornaCentrale() {
  const b = $("btn-centrale");
  b.className = "otturatore " + stato.modo;
  if (stato.modo === "video") {
    if (stato.pausa) b.classList.add("in-pausa");
    b.setAttribute("aria-label", stato.pausa ? "Riprendi" : "Pausa");
  } else {
    if (stato.congelata && !stato.inAttesa) b.classList.add("rifai");
    if (stato.inAttesa) b.classList.add("attesa");
    b.setAttribute("aria-label", stato.congelata ? "Nuova foto" : "Scatta");
  }
}

/** Cattura un'immagine ridimensionata e la restituisce come Blob JPEG. */
function catturaJpeg(sorgente, larghezza, altezza) {
  const q = QUALITA[stato.qualita];
  const k = Math.min(1, q.lato / Math.max(larghezza, altezza));
  const c = document.createElement("canvas");
  c.width = Math.round(larghezza * k);
  c.height = Math.round(altezza * k);
  c.getContext("2d").drawImage(sorgente, 0, 0, c.width, c.height);
  return new Promise((ok) => c.toBlob(ok, "image/jpeg", q.q));
}

/** Modalita' Video: mentre una foto viaggia verso il PC, la successiva viene gia' preparata. */
async function cicloInvio(mio) {
  const v = $("video");
  v.classList.remove("nascosto");
  let prossima = null;                     // foto successiva, gia' in preparazione
  while (stato.ciclo === mio) {
    const t0 = performance.now();
    if (stato.pausa || !v.videoWidth) {
      prossima = null;
      await battito();
      await attesa(1000);
      continue;
    }
    try {
      const blob = await (prossima || catturaJpeg(v, v.videoWidth, v.videoHeight));
      const invio = fetch(api("frame"), { method: "POST", body: blob, headers: { "Content-Type": "image/jpeg" } });
      prossima = catturaJpeg(v, v.videoWidth, v.videoHeight);   // in parallelo all'invio
      const r = await invio;
      const j = await r.json();
      if (stato.ciclo !== mio) break;
      if (!r.ok) { prossima = null; gestisciErrore(r.status, j); await attesa(1500); continue; }
      stato.errori = 0;
      stato.rtt = performance.now() - t0;
      const dt = (performance.now() - stato.ultimoInvio) / 1000;
      stato.ultimoInvio = performance.now();
      if (dt > 0 && dt < 10) stato.fps = stato.fps ? 0.8 * stato.fps + 0.2 / dt : 1 / dt;
      aggiornaPillole(j);
      if (j.versione !== stato.versione) { stato.versione = j.versione; disegnaRisultato(j.risultato); }
    } catch (e) {
      prossima = null;
      stato.errori++;
      aggiornaPillole(null);
      await attesa(Math.min(3000, 500 * stato.errori));
    }
    const resto = 1000 / FPS_MAX - (performance.now() - t0);
    if (resto > 0) await attesa(resto);
  }
}

// ------------------------------------------------------------------ modalita' Foto
async function scattaDalVideo() {
  const v = $("video");
  if (!v.videoWidth) return;
  const c = document.createElement("canvas");             // foto a piena risoluzione per lo schermo
  c.width = v.videoWidth;
  c.height = v.videoHeight;
  const ctx = c.getContext("2d");
  if (stato.facing === "user") { ctx.translate(c.width, 0); ctx.scale(-1, 1); }
  ctx.drawImage(v, 0, 0);
  const img = $("foto");
  img.src = c.toDataURL("image/jpeg", 0.9);
  await img.decode();
  congela();
  inviaFoto(await catturaJpeg(img, img.naturalWidth, img.naturalHeight));
}

async function fotoScelta(e) {
  const file = e.target.files && e.target.files[0];
  e.target.value = "";
  if (!file) return;
  const img = $("foto");
  img.src = URL.createObjectURL(file);
  await img.decode();
  congela();
  inviaFoto(await catturaJpeg(img, img.naturalWidth, img.naturalHeight));
}

function congela() {
  stato.congelata = true;
  $("foto").classList.remove("nascosto");
  $("video").classList.add("nascosto");
  disegnaRisultato(null);
  aggiornaCentrale();
}

function scongela() {
  stato.congelata = false;
  stato.inAttesa = false;
  $("foto").classList.add("nascosto");
  if (stato.stream) $("video").classList.remove("nascosto");
  disegnaRisultato(null);
  aggiornaCentrale();
}

async function inviaFoto(blob) {
  stato.inAttesa = true;
  aggiornaCentrale();
  mostraMessaggio("Invio al PC…", "");
  const t0 = performance.now();
  try {
    const r = await fetch(api("frame"), { method: "POST", body: blob, headers: { "Content-Type": "image/jpeg" } });
    const j = await r.json();
    if (!r.ok) { gestisciErrore(r.status, j); return; }
    stato.rtt = performance.now() - t0;
    aggiornaPillole(j);
    mostraMessaggio("MATLAB sta analizzando…", "");
    const vPrima = j.versione, numero = j.n;
    // il risultato giusto e' quello che MATLAB ha calcolato su questa foto (o una successiva)
    const eDiQuesta = (s) => s && s.risultato && (s.risultato.fotogramma != null
      ? s.risultato.fotogramma >= numero : s.versione !== vPrima);
    for (let i = 0; i < 80 && stato.congelata; i++) {     // aspetta fino a 20 s il nuovo risultato
      await attesa(250);
      const s = await battito(true);
      if (eDiQuesta(s)) {
        stato.versione = s.versione;
        disegnaRisultato(s.risultato);
        return;
      }
    }
    if (stato.congelata) mostraMessaggio("Nessuna risposta da MATLAB", "Il programma MATLAB sta leggendo le immagini?");
  } catch (err) {
    mostraMessaggio("Invio non riuscito", "Controlla il collegamento con il PC.");
  } finally {
    stato.inAttesa = false;
    aggiornaCentrale();
  }
}

// ------------------------------------------------------------------ stato e collegamento
async function battito(senzaDisegno) {
  try {
    const r = await fetch(api("stato"));
    const j = await r.json();
    if (r.ok) {
      stato.errori = 0;
      aggiornaPillole(j);
      if (!senzaDisegno && stato.modo === "video" && j.versione !== stato.versione) {
        stato.versione = j.versione;
        disegnaRisultato(j.risultato);
      }
    } else gestisciErrore(r.status, j);
    return j;
  } catch (e) {
    stato.errori++;
    aggiornaPillole(null);
    return null;
  }
}

function gestisciErrore(codiceHttp, j) {
  if (codiceHttp === 403) {           // il PC ha generato un nuovo codice
    stato.ciclo++;
    fermaStream();
    mostraSchermo("schermo-accoppia");
    impostaStato("Il codice è cambiato", "Inquadra di nuovo il QR code in MATLAB.", true);
    setTimeout(mostraFormCodice, 1500);
  } else if (codiceHttp === 409) {
    $("pillola-testo").textContent = "PC occupato";
    $("pillola-info").textContent = "collegato a un altro telefono";
    $("pillola").className = "pillola vetro scollegata";
  }
}

function aggiornaPillole(j) {
  const p = $("pillola");
  if (!j) {
    p.className = "pillola vetro scollegata";
    $("pillola-testo").textContent = stato.errori > 2 ? "PC non raggiungibile" : "Riconnessione…";
    $("pillola-info").textContent = "";
    $("pillola-matlab").className = "pillola vetro spenta";
    return;
  }
  p.className = "pillola vetro" + (stato.rtt > 800 ? " lenta" : "");
  $("pillola-testo").textContent = stato.pc;
  if (stato.modo === "foto") {
    $("pillola-info").textContent = stato.rtt ? `foto inviata in ${Math.round(stato.rtt)} ms` : "modalità foto";
  } else if (!stato.pausa) {
    $("pillola-info").textContent = `${stato.fps.toFixed(1)} foto/s · ${Math.round(stato.rtt)} ms`;
  }
  $("pillola-matlab").className = "pillola vetro" + (j.matlab ? "" : " spenta");
  $("pillola-matlab-info").textContent = j.matlab ? "sta analizzando" : "non sta leggendo";
}

function fermaStream() {
  if (stato.stream) stato.stream.getTracks().forEach((t) => t.stop());
  stato.stream = null;
}

async function scollega() {
  stato.ciclo++;
  fermaStream();
  try { await fetch(api("ciao_fine"), { method: "POST" }); } catch (e) { /* ok */ }
  mostraSchermo("schermo-accoppia");
  accoppia();
}

function mostraSchermo(id) {
  document.querySelectorAll(".schermo").forEach((s) => s.classList.toggle("attivo", s.id === id));
}

// ------------------------------------------------------------------ risultato da MATLAB
const COLORI = { verde: "#30d158", rosso: "#ff453a", giallo: "#ffd60a", blu: "#0a84ff", grigio: "#8e8e93", arancio: "#ff9f0a" };
const colore = (c, def) => (c ? COLORI[String(c).toLowerCase()] || String(c) : def);
const comeLista = (x) => (x == null ? [] : Array.isArray(x) ? x : [x]);

function mostraMessaggio(titolo, dettaglio) {
  const box = $("risultato");
  box.classList.add("vuoto");
  box.style.backgroundColor = "";
  $("ris-titolo").textContent = titolo;
  $("ris-dettaglio").textContent = dettaglio || "";
  $("ris-voci").innerHTML = "";
}

/**
 * Formato (da MATLAB con jsonencode), tutti i campi facoltativi:
 *   titolo, dettaglio, colore ("verde"|"rosso"|"giallo"|"grigio"|"#RRGGBB"),
 *   voci: [{nome, ok}],  box: [{x, y, w, h, etichetta, colore}] in coordinate 0..1,
 *   cerco: testo con cosa sta cercando MATLAB (es. "frutta · apple, pear · max 10")
 */
function disegnaRisultato(r) {
  stato.ultimoRisultato = r;
  const box = $("risultato");
  const canvas = $("sovrapposizione");
  const ctx = canvas.getContext("2d");
  const dpr = window.devicePixelRatio || 1;
  canvas.width = canvas.clientWidth * dpr;
  canvas.height = canvas.clientHeight * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, canvas.clientWidth, canvas.clientHeight);
  if (!r || typeof r !== "object") return;

  const cerco = r.cerco ? String(r.cerco) : "";
  $("cerco").classList.toggle("nascosto", !cerco);
  $("cerco-testo").textContent = cerco;

  box.classList.remove("vuoto");
  $("ris-titolo").textContent = r.titolo != null ? String(r.titolo) : "";
  $("ris-dettaglio").textContent = r.dettaglio != null ? String(r.dettaglio) : "";
  const c = r.colore ? colore(r.colore) : "";
  box.style.backgroundColor = c && String(r.colore).toLowerCase() !== "grigio" ? c + "cc" : "";
  const voci = $("ris-voci");
  voci.innerHTML = "";
  for (const v of comeLista(r.voci)) {
    const el = document.createElement("span");
    el.className = "voce " + (v.ok === true ? "si" : v.ok === false ? "no" : "");
    el.textContent = (v.ok === true ? "✓ " : v.ok === false ? "✗ " : "") + (v.nome ?? "");
    voci.appendChild(el);
  }

  // riquadri: coordinate 0..1 dell'immagine inviata -> schermo (object-fit: cover)
  const foto = stato.congelata;
  const sorg = foto ? $("foto") : $("video");
  const sw = foto ? sorg.naturalWidth : sorg.videoWidth, sh = foto ? sorg.naturalHeight : sorg.videoHeight;
  if (!sw || !sh) return;
  const W = canvas.clientWidth, H = canvas.clientHeight;
  const s = Math.max(W / sw, H / sh);
  const ox = (W - sw * s) / 2, oy = (H - sh * s) / 2;
  const specchio = !foto && stato.facing === "user";
  ctx.font = "600 13px -apple-system, BlinkMacSystemFont, Roboto, sans-serif";
  for (const b of comeLista(r.box)) {
    let x = b.x * sw * s + ox;
    const y = b.y * sh * s + oy, w = b.w * sw * s, h = b.h * sh * s;
    if (specchio) x = W - x - w;
    const k = colore(b.colore, "#ffd60a");
    ctx.lineWidth = 2.5;
    ctx.strokeStyle = k;
    tondoRett(ctx, x, y, w, h, 10);
    ctx.stroke();
    if (b.etichetta) {
      const t = String(b.etichetta);
      const tw = ctx.measureText(t).width + 16;
      const ty = Math.min(Math.max(y - 28, 4), H - 28);          // l'etichetta resta sempre sullo schermo
      const tx = Math.min(Math.max(x, 4), W - tw - 4);
      ctx.fillStyle = k;
      tondoRett(ctx, tx, ty, tw, 24, 12);
      ctx.fill();
      ctx.fillStyle = testoSu(k);
      ctx.fillText(t, tx + 8, ty + 16.5);
    }
  }
}

function tondoRett(ctx, x, y, w, h, r) {
  r = Math.max(0, Math.min(r, w / 2, h / 2));
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}

/** Testo nero sui colori chiari (giallo), bianco sugli altri. */
function testoSu(c) {
  const m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(c);
  if (!m) return "#fff";
  const [r, g, b] = [m[1], m[2], m[3]].map((h) => parseInt(h, 16));
  return 0.299 * r + 0.587 * g + 0.114 * b > 170 ? "#000" : "#fff";
}
