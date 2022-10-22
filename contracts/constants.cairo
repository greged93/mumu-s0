%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import abs_value, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.memcpy import memcpy

from contracts.events import Check

struct Grid {
    x: felt,
    y: felt,
}

namespace ns_grid {
    const GRID_SIZE = 2;

    func diff{range_check_ptr}(a: Grid, b: Grid) -> (diff: Grid) {
        tempvar abs_x = abs_value(a.x - b.x);
        tempvar abs_y = abs_value(a.y - b.y);
        return (diff=Grid(abs_x, abs_y));
    }
}

namespace ns_atoms {
    const FREE = 0;
    const POSSESSED = 1;
    const DELIVERED = 2;
    const CONSUMED = 3;

    const VANILLA = 0;
    const HAZELNUT = 1;
    const CHOCOLATE = 2;
    const TRUFFLE = 3;

    const ATOM_STATE_SIZE = 6;
}

namespace ns_atom_faucets {
    const FREE = 0;
    const POSSESSED = 1;

    const ATOM_FAUCET_SIZE = 4;
}

namespace ns_mechs {
    const MECH_SIZE = 5;

    const OPEN = 0;
    const CLOSE = 1;

    const SINGLETON = 0;

    const STATIC_COST_SINGLETON = 150;
}

namespace ns_operators {
    const STIR = 0;
    const SHAKE = 1;
    const STEAM = 2;

    const STATIC_COST_STIR = 250;
    const STATIC_COST_SHAKE = 500;
    const STATIC_COST_STEAM = 750;
}

namespace ns_instructions {
    const W = 0;
    const A = 1;
    const S = 2;
    const D = 3;
    const Z = 4;
    const X = 5;
    const SKIP = 6;
}
