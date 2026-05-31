#!/bin/bash 

ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=3 opc@158.180.234.164 -i id_rsa
