%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import abs_value, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy

from contracts.simulator.grid import Grid

struct Summary {
    frame: felt,
    cost: felt,
    static_cost: felt,
    delivered_cost: felt,
    delivered: felt,
}

namespace ns_summary {
    const INF = 2 ** 63 - 1;
    const PRECISION = 10 ** 6;
}

namespace ns_dict {
    const MULTIPLIER = 10 ** 3;
    const MECH_MULTIPLIER = 10 ** 6;
}

namespace ns_grid {
    func diff{range_check_ptr}(a: Grid, b: Grid) -> (diff: Grid) {
        tempvar abs_x = abs_value(a.x - b.x);
        tempvar abs_y = abs_value(a.y - b.y);
        return (diff=Grid(abs_x, abs_y));
    }
}

namespace ns_atoms {
    const FREE = 0;
    const POSSESSED = 1;

    const VANILLA = 0;
    const HAZELNUT = 1;
    const CHOCOLATE = 2;
    const TRUFFLE = 3;
    const SAFFRON = 4;
    const TURTLE = 5;
    const SANDGLASS = 6;
    const WILTED_ROSE = 7;

    const ATOM_STATE_SIZE = 6;
}

namespace ns_atom_faucets {
    const FREE = 0;
    const POSSESSED = 1;

    const ATOM_FAUCET_SIZE = 4;
}

namespace ns_atom_sinks {
    const ATOM_SINK_SIZE = 3;
}

namespace ns_mechs {
    const INPUT_MECH_SIZE = 5;
    const MECH_SIZE = 6;

    const OPEN = 0;
    const CLOSE = 1;

    const SINGLETON = 0;

    const STATIC_COST_SINGLETON = 150;
}

namespace ns_operators {
    const STIR = 0;
    const SHAKE = 1;
    const STEAM = 2;
    const SMASH = 3;
    const EVOLVE = 4;
    const SLOW = 5;
    const WILT = 6;
    const BAKE = 7;

    const STATIC_COST_STIR = 250;
    const STATIC_COST_SHAKE = 500;
    const STATIC_COST_STEAM = 750;
    const STATIC_COST_SMASH = 1000;
    const STATIC_COST_EVOLVE = 500;
    const STATIC_COST_SLOW = 750;
    const STATIC_COST_WILT = 750;
    const STATIC_COST_BAKE = 1000;
}

// TODO add a careless drop which makes the atom dissapear if there is already a atom on the same part of the board.
namespace ns_instructions {
    const W = 0;  // up
    const A = 1;  // left
    const S = 2;  // down
    const D = 3;  // right
    const Z = 4;  // get
    const X = 5;  // put
    const G = 6;  // block-get
    const H = 7;  // block-put
    const SKIP = 8;  // skip
}

// TODO careless drop cost
namespace ns_instructions_cost {
    const SINGLETON_MOVE_EMPTY = 10;
    const SINGLETON_MOVE_CARRY = 20;
    const SINGLETON_GET = 25;
    const SINGLETON_PUT = 25;
    const SINGLETON_BLOCKED = 3;
}
