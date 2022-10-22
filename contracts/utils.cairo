%lang starknet

from contracts.events import Check
from contracts.constants import ns_grid, ns_mechs, ns_atoms, Grid
from contracts.mechs import MechState
from contracts.atoms import AtomState

func emit_arr{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: felt*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr]);
    return emit_arr(arr_len - 1, arr + 1);
}

func emit_grid_arr{syscall_ptr: felt*, range_check_ptr}(arr_len: felt, arr: Grid*) {
    if (arr_len == 0) {
        return ();
    }
    Check.emit(value=[arr].x);
    Check.emit(value=[arr].y);
    return emit_arr(arr_len - 1, arr + ns_grid.GRID_SIZE);
}

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
