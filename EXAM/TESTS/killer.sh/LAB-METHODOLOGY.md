# Metodologia comune dei lab CNPE

Tutti i lab `*-lab` e `cnpe-gaps-*` seguono lo stesso contratto operativo.

I pacchetti `cnpe-fixed` e `cnpe-alt` sono simulatori completi multi-parte:
riusano lo stesso formato di ticket ed evidenze, ma mantengono il proprio
bootstrap integrato e non sono trattati come lab tematici autonomi.

## Struttura

- `README.md`: obiettivo, dominio CNPE, avvio, rigenerazione e validazione.
- `domande.md`: 20 task, riferimenti e soluzioni aggregate.
- `setup-<lab>.sh`: prepara cluster e starter.
- `setup-<lab>-kind.sh`: avvia la stessa esperienza su Kind.
- `lab-question-layout.sh`: genera `QUESTION.md`, `evidence.txt` e indice.
- `validate-<lab>.sh`: controlla offline il contratto metodologico.

Il setup genera 20 directory logiche `01`-`20`. Gli starter possono essere
indipendenti oppure condivisi tra piu' domande quando lo scenario lo richiede.

## Formato delle domande

Ogni domanda usa un heading:

```text
### QN - Titolo
```

La traccia deve indicare:

1. directory o scenario su cui lavorare;
2. file o risorse da modificare;
3. stato finale osservabile;
4. almeno un comando o criterio di verifica;
5. eventuale evidenza da conservare.

I suggerimenti devono orientare verso API e diagnostica, senza contenere la
soluzione completa. Le soluzioni rimangono dopo `## Soluzioni` oppure
`## Tracce di soluzione` e non vengono copiate nei singoli `QUESTION.md`.

## Setup

Ogni setup espone:

- `COURSE_DIR` per scegliere la directory generata;
- `LAB_FORCE=true` per rigenerare;
- `CLUSTER_PROVIDER` quando sono supportiti piu' backend;
- wrapper Kind separato;
- marker `.initialized` quando il setup genera materiale locale.

Gli script non devono rimuovere directory arbitrarie. Prima di un
`rm -rf`, il target deve essere il `COURSE_DIR` esplicitamente previsto.

## Verifica

Il candidato verifica prima il risultato runtime e poi salva, quando
richiesto, comandi e output sintetici in `evidence.txt`.

Il validatore metodologico controlla offline:

- presenza dei file standard;
- esattamente 20 heading;
- numerazione continua Q1-Q20;
- heading con trattino ASCII;
- presenza della sezione soluzioni;
- presenza di percorso, verifica e tip nelle tracce;
- corretta estrazione dei 20 `QUESTION.md`;
- assenza delle soluzioni nei task estratti.

I lab con fixture complesse possono aggiungere controlli specifici al proprio
validatore.

Controllo statico dell'intera suite:

```bash
bash validate-all-labs.sh
```

Per eseguire anche i validatori specifici:

```bash
FULL_VALIDATION=true bash validate-all-labs.sh
```
