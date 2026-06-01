# CNPE Simulator - Batteria 14 - Risposte
> Retake Final Simulation 2
> Focus: Mixed hard tasks across all CNPE domains

## Bootstrap Git da Gitea

```bash
GITEA_URL="${GITEA_URL:-http://158.180.234.164:3000}"
GITEA_TOKEN="${GITEA_TOKEN:-19e1a2f01f5fc81ec0038e91128c18ed21eb8c4e}"
GITEA_OWNER="$(curl -fsS -H "Authorization: token ${GITEA_TOKEN}" "${GITEA_URL%/}/api/v1/user" | sed -n 's/.*"login":"\([^"]*\)".*/\1/p' | head -n1)"
for q in 1 3 5 9 10 11 17 19; do
  mkdir -p /course/${q}
  rm -rf /course/${q}/repo-b14
  git clone "${GITEA_URL%/}/${GITEA_OWNER}/cnpe-b14-q${q}.git" "/course/${q}/repo-b14"
done
```

## Metodo rapido
1. Individua la risorsa principale.
2. Applica patch minima e reversibile.
3. Verifica stato con get/describe/logs/events.
4. Salva output di prova.

## Question 1 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/1/b14-q1.txt.

## Question 2 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/2/b14-q2.txt.

## Question 3 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/3/b14-q3.txt.

## Question 4 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/4/b14-q4.txt.

## Question 5 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/5/b14-q5.txt.

## Question 6 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/6/b14-q6.txt.

## Question 7 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/7/b14-q7.txt.

## Question 8 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/8/b14-q8.txt.

## Question 9 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/9/b14-q9.txt.

## Question 10 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/10/b14-q10.txt.

## Question 11 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/11/b14-q11.txt.

## Question 12 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/12/b14-q12.txt.

## Question 13 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/13/b14-q13.txt.

## Question 14 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/14/b14-q14.txt.

## Question 15 - Guida

- Comandi base: kubectl get, kubectl describe, kubectl get events.
- Conferma stato finale del controller.
- Archivia output in /course/15/b14-q15.txt.

