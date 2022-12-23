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
    "C": 8,
    ".": 50,
}
DESCRIPTIONS = [
    "this is a recycler",
    "this is a deliverer",
    "this is the main mech",
]


def convert_mech(mech={}):
    if not mech:
        raise ValueError("expected mech")
    mech_id = mech["id"]
    id = int(mech_id[-1 - len(mech_id) % 5 :])
    description = mech["description"]
    if type(description) == str:
        description = int.from_bytes(
            mech["description"].encode("utf8"), "big"
        )
    return (
        id,
        MECH_TYPE[mech["typ"]],
        MECH_STATUS[mech["status"]],
        (mech["index"]["x"], mech["index"]["y"]),
        description,
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


def fill(path_from, path_to):
    from random import randint

    with open(path_from, "r") as f:
        data = json.load(f)

    for mech in data["mechs"]:
        mech["description"] = int.from_bytes(
            DESCRIPTIONS[randint(0, 2)].encode("utf8"), "big"
        )

    with open(path_to, "w") as f:
        json.dump(data, f)


def test():
    (mechs, instructions_length, instructions, inputs, outputs, types) = import_json(
        "./tests/test-cases/test0_description.json"
    )
    mechs = [mech[0:4] for mech in mechs]
    mechs_test = [
        (0, 0, 0, (0, 0)),
        (1, 0, 0, (0, 0)),
        (2, 0, 0, (3, 0)),
        (3, 0, 0, (4, 2)),
        (4, 0, 0, (3, 0)),
        (5, 0, 0, (5, 4)),
        (6, 0, 0, (6, 5)),
        (7, 0, 0, (6, 4)),
        (8, 0, 0, (2, 5)),
        (9, 0, 0, (4, 5)),
    ]
    inputs_test = [
        (1, 0),
        (2, 0),
        (1, 1),
        (2, 1),
        (4, 0),
        (4, 1),
        (3, 3),
        (4, 3),
        (5, 3),
        (1, 5),
    ]
    outputs_test = [
        (3, 0),
        (3, 1),
        (4, 2),
        (5, 4),
        (6, 4),
        (2, 5),
        (3, 5),
        (4, 5),
        (5, 5),
        (6, 5),
    ]
    types_test = [0, 0, 1, 2, 3]

    assert mechs == mechs_test, "mechs error"
    assert inputs == inputs_test, "inputs error"
    assert outputs == outputs_test, "outputs error"
    assert types == types_test, "types error"
    assert sum(instructions_length) == len(instructions), "instruction length error"
