%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy

from contracts.simulator.constants import Grid, ns_atoms, ns_atom_faucets, ns_atom_sinks, Summary

struct AtomState {
    id: felt,
    type: felt,
    status: felt,
    index: Grid,
    possessed_by: felt,
}

struct AtomFaucetState {
    id: felt,
    type: felt,
    index: Grid,
}

struct AtomSinkState {
    id: felt,
    index: Grid,
}

// @notice Iterates on atom sinks
// @param atom_sinks The array of sinks
// @param atoms The arrays of atoms
// @param delivered The current amount of target atoms delivered
// @return atoms_new The array of updated atoms
// @return delivered_increase The increase of target atoms delivered
func iterate_sinks{range_check_ptr}(
    atom_sinks_len: felt,
    atom_sinks: AtomSinkState*,
    atoms_len: felt,
    atoms: AtomState*,
    delivered: felt,
) -> (atoms_len_new: felt, atoms_new: AtomState*, delivered_increase: felt) {
    if (atom_sinks_len == 0) {
        return (atoms_len_new=atoms_len, atoms_new=atoms, delivered_increase=delivered);
    }
    tempvar sink = [atom_sinks];
    let (atoms_len_new, atoms_new, is_delivered) = sink_atoms(sink, 0, atoms_len, atoms);
    return iterate_sinks(
        atom_sinks_len - 1,
        atom_sinks + ns_atom_sinks.ATOM_SINK_SIZE,
        atoms_len_new,
        atoms_new,
        delivered + is_delivered,
    );
}

// @notice Iterates atoms for one sink
// @param sink The sink
// @param i The atom index
// @param atoms The arrays of atoms
// @return atoms_new The array of updated atoms
// @return is_delivered 1 if target atom delivered, 0 otherwise
func sink_atoms{range_check_ptr}(
    sink: AtomSinkState, i: felt, atoms_len: felt, atoms: AtomState*
) -> (atoms_len_new: felt, atoms_new: AtomState*, is_delivered: felt) {
    alloc_locals;
    if (atoms_len == i) {
        return (atoms_len_new=atoms_len, atoms_new=atoms, is_delivered=0);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (sink.index.x == atom.index.x and sink.index.y == atom.index.y and
        atom.status == ns_atoms.FREE) {
        // TODO make a generic copy functin which takes i, atoms and AtomState and returns atoms_new
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        memcpy(atoms_new + len_1, atoms + len_1 + ns_atoms.ATOM_STATE_SIZE, len_2);
        tempvar increase;
        if (atom.type == ns_atoms.SAFFRON) {
            assert increase = 1;
        } else {
            assert increase = 0;
        }
        return (atoms_len_new=atoms_len - 1, atoms_new=atoms_new, is_delivered=increase);
    }
    return sink_atoms(sink, i + 1, atoms_len, atoms);
}

// @notice Updates a atom's position
// @param mech_id The id of the mech
// @param pos The new position
// @param i The index for atoms
// @param atoms The arrays of atoms
// @return is_moved 1 if an atom was moved, 0 otherwise
// @return atoms_new The array of updated atoms
func update_atoms_moved{syscall_ptr: felt*, range_check_ptr}(
    mech_id: felt, pos: Grid, i: felt, atoms_len: felt, atoms: AtomState*
) -> (is_moved: felt, atoms_new: AtomState*) {
    alloc_locals;
    if (atoms_len == i) {
        return (0, atoms);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (atom.status == ns_atoms.FREE) {
        return update_atoms_moved(mech_id, pos, i + 1, atoms_len, atoms);
    }
    if (atom.possessed_by == mech_id and atom.status == ns_atoms.POSSESSED) {
        // TODO make a generic copy function which takes i, atoms and AtomState and returns atoms_new
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        assert [atoms_new + len_1] = AtomState(atom.id, atom.type, atom.status, pos, mech_id);
        memcpy(
            atoms_new + len_1 + ns_atoms.ATOM_STATE_SIZE,
            atoms + len_1 + ns_atoms.ATOM_STATE_SIZE,
            len_2,
        );
        return (1, atoms_new);
    }
    return update_atoms_moved(mech_id, pos, i + 1, atoms_len, atoms);
}

// @notice Releases an atom from a mech
// @param mech_id The id of the mech
// @param pos The new position
// @param i The index for atoms
// @param atoms The arrays of atoms
// @return atoms_new The array of updated atoms
func release_atom{range_check_ptr}(
    mech_id: felt, pos: Grid, i: felt, atoms_len: felt, atoms: AtomState*
) -> (atoms_new: AtomState*) {
    alloc_locals;
    if (atoms_len == i) {
        return (atoms_new=atoms);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (atom.status == ns_atoms.POSSESSED and atom.possessed_by == mech_id) {
        // TODO make a generic copy function which takes i, atoms and AtomState and returns atoms_new
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        assert [atoms_new + len_1] = AtomState(atom.id, atom.type, ns_atoms.FREE, pos, 0);
        memcpy(
            atoms_new + len_1 + ns_atoms.ATOM_STATE_SIZE,
            atoms + len_1 + ns_atoms.ATOM_STATE_SIZE,
            len_2,
        );
        return (atoms_new=atoms_new);
    }
    return release_atom(mech_id, pos, i + 1, atoms_len, atoms);
}

// @notice Picks up an atom for a mech
// @param mech_id The id of the mech
// @param pos The new position
// @param i The index for atoms
// @param atoms The arrays of atoms
// @return atoms_new The array of updated atoms
func pick_up_atom{range_check_ptr}(
    mech_id: felt, pos: Grid, i: felt, atoms_len: felt, atoms: AtomState*
) -> (atoms_new: AtomState*) {
    alloc_locals;
    if (atoms_len == i) {
        return (atoms_new=atoms);
    }
    tempvar atom = [atoms + i * ns_atoms.ATOM_STATE_SIZE];
    if (atom.status == ns_atoms.FREE and pos.x == atom.index.x and pos.y == atom.index.y) {
        let (atoms_new: AtomState*) = alloc();
        tempvar len_1 = i * ns_atoms.ATOM_STATE_SIZE;
        tempvar len_2 = (atoms_len - i - 1) * ns_atoms.ATOM_STATE_SIZE;
        memcpy(atoms_new, atoms, len_1);
        assert [atoms_new + len_1] = AtomState(atom.id, atom.type, ns_atoms.POSSESSED, pos, mech_id);
        memcpy(
            atoms_new + len_1 + ns_atoms.ATOM_STATE_SIZE,
            atoms + len_1 + ns_atoms.ATOM_STATE_SIZE,
            len_2,
        );
        return (atoms_new=atoms_new);
    }
    return pick_up_atom(mech_id, pos, i + 1, atoms_len, atoms);
}

// @notice Populates the faucet
// @param faucet The atom faucet
// @param atoms The arrays of atoms
func populate_faucet{range_check_ptr}(
    faucet: AtomFaucetState, atoms_len: felt, atoms: AtomState*
) -> felt {
    alloc_locals;
    let is_free = check_grid_free(faucet.index, atoms_len, atoms);
    if (is_free == 1) {
        assert [atoms + atoms_len * ns_atoms.ATOM_STATE_SIZE] = AtomState(atoms_len, faucet.type, ns_atoms.FREE, Grid(faucet.index.x, faucet.index.y), 0);
        return atoms_len + 1;
    }
    return atoms_len;
}

// @notice Checks the position is free of atoms
// @param pos The position on the board
// @param atoms The arrays of atoms
// @return 1 if the position is free of atoms, 0 otherwise
func check_grid_free{range_check_ptr}(pos: Grid, atoms_len: felt, atoms: AtomState*) -> felt {
    if (atoms_len == 0) {
        return 1;
    }
    tempvar atom = [atoms];
    if (pos.x == atom.index.x and pos.y == atom.index.y and atom.status == ns_atoms.FREE) {
        return 0;
    }
    return check_grid_free(pos, atoms_len - 1, atoms + ns_atoms.ATOM_STATE_SIZE);
}

// @notice Checks the position is filled with an atom
// @param pos The position on the board
// @param atoms The arrays of atoms
// @return 1 if the position is filled with an atom, 0 otherwise
func check_grid_filled{range_check_ptr}(pos: Grid, atoms_len: felt, atoms: AtomState*) -> felt {
    if (atoms_len == 0) {
        return 0;
    }
    tempvar atom = [atoms];
    if (pos.x == atom.index.x and pos.y == atom.index.y and atom.status == ns_atoms.FREE) {
        return 1;
    }
    return check_grid_filled(pos, atoms_len - 1, atoms + ns_atoms.ATOM_STATE_SIZE);
}
