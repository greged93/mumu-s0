import json
import logging

LOGGER = logging.getLogger(__name__)
LOGGER.setLevel(5)

MECH_STATUS = {
    "open": 0,
    "close": 1,
}
MECH_TYPE = {
    "SINGLETON": 0,
}
OPERATOR_TYPE = {
    "&": 0,
    "%": 1,
    "^": 2,
    "#": 3,
    "§": 4,
    "|": 5,
    "~": 6,
    "!": 7,
}
INSTRUCTIONS = {
    "W": 0,
    "A": 1,
    "S": 2,
    "D": 3,
    "Z": 4,
    "X": 5,
    "G": 6,
    "H": 7,
    ".": 8,
}


def convert_mech(mech={}):
    if not mech:
        raise ValueError("expected mech")
    mech_id = mech["id"]
    id = int(mech_id[-1 - len(mech_id) % 5 :])
    return (
        id,
        MECH_TYPE[mech["typ"]],
        MECH_STATUS[mech["status"]],
        (mech["index"]["x"], mech["index"]["y"]),
    )


def convert_operator(operator={}):
    if not operator:
        raise ValueError("expected operator")
    return OPERATOR_TYPE[operator["typ"]["symbol"]]


def convert_instructions(instructions=[]):
    if not instructions:
        raise ValueError("expected instructions")
    return [INSTRUCTIONS[i] for i in instructions if i != ","]


def import_json(path: str):
    with open(path, "r") as f:
        data = json.load(f)

    mechs = [convert_mech(mech) for mech in data["mechs"]]
    inputs = [
        (input["x"], input["y"]) for op in data["operators"] for input in op["input"]
    ]
    outputs = [
        (output["x"], output["y"])
        for op in data["operators"]
        for output in op["output"]
    ]

    programs = [p.upper() for p in data["programs"]]
    instructions_length = [len(x) // 2 + 1 for x in programs]
    instructions = sum(list(map(convert_instructions, programs)), [])
    types = [convert_operator(op) for op in data["operators"]]

    return mechs, instructions_length, instructions, inputs, outputs, types


def test():
    (mechs, instructions_length, instructions, inputs, outputs, types) = import_json(
        "./tests/test-cases/test3.json"
    )
    mechs_test = [
        (0, 0, 0, (0, 0)),
        (1, 0, 0, (0, 0)),
        (2, 0, 0, (0, 0)),
        (3, 0, 0, (0, 0)),
        (4, 0, 0, (3, 0)),
        (5, 0, 0, (3, 1)),
        (6, 0, 0, (2, 2)),
        (7, 0, 0, (2, 3)),
        (8, 0, 0, (4, 2)),
        (9, 0, 0, (4, 3)),
        (10, 0, 0, (4, 0)),
        (11, 0, 0, (5, 4)),
        (12, 0, 0, (6, 0)),
        (13, 0, 0, (6, 1)),
        (14, 0, 0, (6, 2)),
        (15, 0, 0, (6, 3)),
        (16, 0, 0, (6, 4)),
        (17, 0, 0, (5, 5)),
        (18, 0, 0, (7, 3)),
        (19, 0, 0, (7, 3)),
    ]
    inputs_test = [
        (1, 0),
        (2, 0),
        (1, 1),
        (2, 1),
        (0, 2),
        (1, 2),
        (0, 3),
        (1, 3),
        (4, 0),
        (4, 1),
        (3, 2),
        (3, 3),
        (5, 1),
        (5, 2),
        (5, 3),
        (6, 5),
        (7, 1),
        (7, 2),
    ]
    outputs_test = [
        (3, 0),
        (3, 1),
        (2, 2),
        (2, 3),
        (4, 2),
        (4, 3),
        (5, 4),
        (5, 5),
        (6, 4),
        (6, 3),
        (6, 2),
        (6, 1),
        (6, 0),
        (7, 3),
    ]
    types_test = [0, 0, 0, 0, 1, 1, 2, 3, 0]

    assert mechs == mechs_test, "mechs error"
    assert inputs == inputs_test, "inputs error"
    assert outputs == outputs_test, "outputs error"
    assert types == types_test, "types error"
    assert sum(instructions_length) == len(instructions), "instruction length error"
