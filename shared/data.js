// ════════════════════════════════════════════════════════
// DATOS COMPARTIDOS · TETRAPLASTIC
// Personal, clientes, procesos, estados, config
// ════════════════════════════════════════════════════════

// ── Configuración base ─────────────────────────────────
const CFG = {
  cap_und_h: 1200,   // und/hora/operador (calibrado con tus datos)
  turno_h:   12,     // horas por turno
};

// ── Procesos por área ──────────────────────────────────
const PROCS = {
  armado:      { label:'Armado',      area:'tapas', color:'var(--teal)' },
  banda:       { label:'Banda',       area:'tapas', color:'var(--teal)' },
  liner:       { label:'Liner',       area:'tapas', color:'var(--teal)' },
  impresion:   { label:'Impresión',   area:'tapas', color:'var(--teal)' },
  encajado:    { label:'Encajado',    area:'tapas', color:'var(--teal)' },
  serigrafia:  { label:'Serigrafía',  area:'serig', color:'var(--serig-m)' },
  tampografia: { label:'Tampografía', area:'serig', color:'var(--serig-m)' },
};

// ── Estados de solicitud ───────────────────────────────
const ESTADOS = {
  nueva:{css:'p-nueva',lbl:'Nueva'}, programada:{css:'p-prog',lbl:'Programada'},
  proceso:{css:'p-proc',lbl:'En proceso'}, lista:{css:'p-lista',lbl:'Lista'},
  entregada:{css:'p-ent',lbl:'Entregada'}
};

// ── Personal por área ──────────────────────────────────
let personal = {
  tapas: [
    { id:'T0',  nombre:'Heidy',            ini:'HY', color:'#0D4035', proc:'Supervisora', presente:true,  turno:'AM',   rol:'supervisor' },
    { id:'T1',  nombre:'Yenifer Lopez',    ini:'YL', color:'#1A6B5B', proc:'Armado',      presente:true,  turno:'AM',   rol:'operador' },
    { id:'T2',  nombre:'Mishel Arriaza',   ini:'MA', color:'#1E7D6A', proc:'Armado',      presente:true,  turno:'AM',   rol:'operador' },
    { id:'T3',  nombre:'Ana Chun',         ini:'AC', color:'#247A68', proc:'Banda',       presente:true,  turno:'AM',   rol:'operador' },
    { id:'T4',  nombre:'Violeta Bartolome',ini:'VB', color:'#1A3A6B', proc:'Banda',       presente:true,  turno:'AM',   rol:'operador' },
    { id:'T5',  nombre:'Elsa Tul',         ini:'ET', color:'#3D1A6B', proc:'Liner',       presente:true,  turno:'AM',   rol:'operador' },
    { id:'T6',  nombre:'Noemi Alvarez',    ini:'NA', color:'#5A2D9E', proc:'Liner',       presente:true,  turno:'AM',   rol:'operador' },
    { id:'T7',  nombre:'Carlos Ascuc',     ini:'CA', color:'#5B4A1A', proc:'Armado',      presente:true,  turno:'AM',   rol:'operador' },
    { id:'T8',  nombre:'Selvin Rivera',    ini:'SR', color:'#5B1A1A', proc:'Banda',       presente:true,  turno:'AM',   rol:'operador' },
    { id:'T9',  nombre:'Daniel Ochoa',     ini:'DO', color:'#1A5B3A', proc:'Liner',       presente:true,  turno:'AM',   rol:'operador' },

  ],
  serig: [
    { id:'S0',  nombre:'Luis Cordova',       ini:'LC', color:'#0D4035', proc:'Supervisor',  presente:true,  turno:'AM',   rol:'supervisor' },
    { id:'S1',  nombre:'Gabriela Gonzales',  ini:'GG', color:'#1A6B5B', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
    { id:'S2',  nombre:'Suri Cabrera',       ini:'SC', color:'#3D1A6B', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
    { id:'S3',  nombre:'Jackeline Hernandez',ini:'JH', color:'#5A2D9E', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
    { id:'S4',  nombre:'Nicolle Garcia',     ini:'NG', color:'#1A3A6B', proc:'Tampografía', presente:true,  turno:'AM',   rol:'operador' },
    { id:'S5',  nombre:'Andy Lopez',         ini:'AL', color:'#1A5B3A', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
    { id:'S6',  nombre:'Victor Monzon',      ini:'VM', color:'#5B1A1A', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
    { id:'S7',  nombre:'Esvin Xicay',        ini:'EX', color:'#5B4A1A', proc:'Serigrafía',  presente:true,  turno:'AM',   rol:'operador' },
  ],
};


// ── Clientes ───────────────────────────────────────────
const CLIENTES = [
  'A. CORP UNIVERSAL',
  'AMERICAN NATURAL',
  'ANCORA (HN)',
  'BELLEZA S.A.',
  'CALLE DE LA PLAZA',
  'CAVE LULU (HN)',
  'CHAMER (HN)',
  'CLEMENTE VELASQUEZ ROCA',
  'DAROSA (HN)',
  'DISUFIX',
  'DISTRIBUIDORA DEL CARIBE',
  'ERICK DAVID CASTRO VELIZ',
  'ETIFLEX',
  'FARMAYA',
  'FLUSHING',
  'HUGO FERNANDO DURAN',
  'INCOGUA',
  'INTERCORP',
  'JOSE IBAÑEZ',
  'JULIA ALVARADO',
  'NATUFARMA',
  'PETROPLASTIC',
  'ROMO S.A.',
  'SCENTIA',
  'SHALOM',
  'SINERGIA',
  'TECNIPLAST',
  'VESA',
];
