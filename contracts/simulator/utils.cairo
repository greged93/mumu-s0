%lang starknet

from contracts.simulator.events import Check
from contracts.simulator.constants import ns_grid, ns_mechs, ns_atoms
from contracts.simulator.grid import Grid, GRID_SIZE
from contracts.simulator.mechs import MechState
from contracts.simulator.atoms import AtomState

// @notice Emits values in the array
// @param arr_len The length of the array
// @param arr The array
func emit_arr{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: felt*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr]);
    return emit_arr(arr_len - 1, arr + 1);
}

// @notice Emits the grid values in the array
// @param arr_len The length of the array
// @param arr The array of grids
func emit_grid_arr{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: Grid*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr].x);
    Check.emit(value=[arr].y);
    return emit_arr(arr_len - 1, arr + GRID_SIZE);
}

// @notice Emits the mechs values in the array
// @param arr_len The length of the array
// @param arr The array of mechs
func emit_mechs{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: MechState*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr].id);
    Check.emit(value=[arr].type);
    Check.emit(value=[arr].status);
    Check.emit(value=[arr].index.x);
    Check.emit(value=[arr].index.y);
    return emit_mechs(arr_len - 1, arr + ns_mechs.MECH_SIZE);
}

// @notice Emits the atoms values in the array
// @param arr_len The length of the array
// @param arr The array of atoms
func emit_atoms{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: AtomState*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr].id);
    Check.emit(value=[arr].type);
    Check.emit(value=[arr].status);
    Check.emit(value=[arr].index.x);
    Check.emit(value=[arr].index.y);
    Check.emit(value=[arr].possessed_by);
    return emit_atoms(arr_len - 1, arr + ns_atoms.ATOM_STATE_SIZE);
}
