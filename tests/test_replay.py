import json
import pytest
import logging
import time

LOGGER = logging.getLogger(__name__)

FRAME = 0
DIMENSION = 7


def make_board(mechs, atoms):
    board = [[0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0],
             [0, 0, 0, 0, 0, 0, 0]]
    for (i, m) in enumerate(mechs):
        pos = m[f'{i}'][3]
        board[pos[1]][pos[0]] = 1
    return board


def test_replay():
    path = 'artifacts/test_simulator.json' if FRAME == 1 else 'artifacts/test_simulator_short.json'
    with open(path, 'r') as f:
        frames_str = json.load(f)
        frames = json.loads(frames_str)

    for f in frames['frames']:
        board = make_board(f['mechs'], f['atoms'])
        print('\n')
        for line in board:
            print(f'{line}')
        print('\n')
