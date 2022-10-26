%lang starknet

struct Grid {
    x: felt,
    y: felt,
}

const GRID_SIZE = 2;

func check_position{range_check_ptr}(pos: Grid, i: felt, positions_len: felt, positions: Grid*) -> (
    is_at_position: felt, position_index: felt
) {
    if (positions_len == 0) {
        return (0, 0);
    }
    tempvar p = [positions];
    if (p.x == pos.x and p.y == pos.y) {
        return (1, i);
    }
    return check_position(pos, i + 1, positions_len - 1, positions + GRID_SIZE);
}
