%lang starknet

struct Grid {
    x: felt,
    y: felt,
}

const GRID_SIZE = 2;

// @notice Check if a position matches an array of positions
// @param pos The position to check for
// @param i The index of positions
// @param positions The array of positions to check in
// @return is_at_position 1 if pos matches some position in positions, 0 otherwise
// @return position_index The index in positions matched by pos
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
