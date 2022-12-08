# Hashistack Development Environment

Setup a simple and powerful Hashistack locally to play around with.

## How to use

To setup, run `./setup.sh` and wait for your stack to initialize.
When you are finished, run `./destroy.sh` and we will clean up the entire stack.

If you don't have any of the tools downloaded locally this script will download
and store them locally in the `.cache` directory.

### Note
This script requires root as some features within the products do not work
without root, primarily Consul connect.

## Why?
I wrote this up because I got tired of spinning up the hashistack across
multiple terminals when doing Waypoint development.

This repo spins up Consul, Vault, and Nomad in development mode and starts them
with sensible configurations so they all can communicate with each other out of
the box. Services deployed within Nomad automatically register within Consul.
Nomad has the root token of Vault configured so that we can automatically pull
secrets out of Vault.

Obviously this should not be used in a production setting. Please do not use in
production. Take inspiration from playing around in a relatively safe
and quickly iterative environment to test out things you want to try but never
could in a real production environment.

## Future Features

- [  ] Proper Consul Connect support
- [  ] Consul DNS within Nomad
- [  ] Proper ACLs if desired
- [  ] Maybe Add Terraform
    > This is a maybe because this was intended to aid me in Waypoint
    > development with the rest of the Hashistack. Terraform, while it falls
    > into the Hashistack, usually happens in a step preceding Waypoint and
    > thus isn't a priority right now.
