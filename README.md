# Tic-Tac-Toe

This repository contains an implementation of Tic-Tac-Toe in solidity. At a high-level the game consists of two smart contracts, a factory contract and a game instance contract. The factory contract can be called by any address to initiate a new match (deploy a new game instace contract), but the initiator of the game must challenge a specific address. Once the player containing this specific address accepts the challenge the game is in session and continues until either player wins or there is a draw.
