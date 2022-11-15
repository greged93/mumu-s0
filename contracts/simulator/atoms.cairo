%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.memcpy import memcpy
from starkware.cairo.common.dict import dict_write, dict_read
from starkware.cairo.common.dict_access import DictAccess

from contracts.simulator.constants import (
    Grid,
    ns_atoms,
    ns_atom_faucets,
    ns_atom_sinks,
    ns_dict,
    Summary,
)

struct AtomState {
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
// @param atoms The dictionary of atoms
// @param delivered The current amount of target atoms delivered
// @return atoms_new The dictionary of updated atoms
// @return delivered_increase The increase of target atoms delivered
func iterate_sinks{range_check_ptr}(
    atom_sinks_len: felt, atom_sinks: AtomSinkState*, atoms: DictAccess*, delivered: felt
) -> (atoms_new: DictAccess*, delivered_increase: felt) {
    if (atom_sinks_len == 0) {
        return (atoms_new=atoms, delivered_increase=delivered);
    }
    tempvar sink = [atom_sinks];
    let (atoms_new, is_delivered) = sink_atoms(sink, atoms);
    return iterate_sinks(
        atom_sinks_len - 1,
        atom_sinks + ns_atom_sinks.ATOM_SINK_SIZE,
        atoms_new,
        delivered + is_delivered,
    );
}

// @notice Iterates atoms for one sink
// @param sink The sink
// @param atoms The dictionary of atoms
// @return atoms_new The dictionary of updated atoms
// @return is_delivered 1 if target atom delivered, 0 otherwise
func sink_atoms{range_check_ptr}(sink: AtomSinkState, atoms: DictAccess*) -> (
    atoms_new: DictAccess*, is_delivered: felt
) {
    alloc_locals;
    tempvar key = sink.index.x * ns_dict.MULTIPLIER + sink.index.y;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    if (ptr == 0) {
        return (atoms_new=atoms, is_delivered=0);
    }
    tempvar atom = cast(ptr, AtomState*);
    if (atom.status == ns_atoms.FREE) {
        if (atom.type == ns_atoms.SAFFRON) {
            tempvar increase = 1;
        } else {
            tempvar increase = 0;
        }
        dict_write{dict_ptr=atoms}(key=key, new_value=0);
        return (atoms_new=atoms, is_delivered=increase);
    }
    return (atoms_new=atoms, is_delivered=0);
}

// @notice Releases an atom from a mech
// @param mech_id The id of the mech
// @param pos The new position
// @param atoms The dictionary of atoms
// @return atoms_new The dictionary of updated atoms
func release_atom{range_check_ptr}(mech_id: felt, pos: Grid, atoms: DictAccess*) -> (
    atoms_new: DictAccess*
) {
    alloc_locals;
    tempvar key = (mech_id + 1) * ns_dict.MECH_MULTIPLIER;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    tempvar atom = cast(ptr, AtomState*);
    tempvar atom_new: AtomState* = new AtomState(
        atom.type, ns_atoms.FREE, Grid(pos.x, pos.y), 0
        );
    tempvar key_new = pos.x * ns_dict.MULTIPLIER + pos.y;
    dict_write{dict_ptr=atoms}(key=key_new, new_value=cast(atom_new, felt));
    dict_write{dict_ptr=atoms}(key=key, new_value=0);
    return (atoms_new=atoms);
}

// @notice Picks up an atom for a mech
// @param mech_id The id of the mech
// @param pos The new position
// @param i The index for atoms
// @param atoms The dictionary of atoms
// @return atoms_new The dictionary of updated atoms
func pick_up_atom{range_check_ptr}(mech_id: felt, pos: Grid, atoms: DictAccess*) -> (
    atoms_new: DictAccess*
) {
    alloc_locals;
    tempvar key = pos.x * ns_dict.MULTIPLIER + pos.y;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    tempvar atom = cast(ptr, AtomState*);
    tempvar atom_new: AtomState* = new AtomState(
        atom.type, ns_atoms.POSSESSED, Grid(pos.x, pos.y), mech_id
        );
    tempvar key_new = (mech_id + 1) * ns_dict.MECH_MULTIPLIER;
    dict_write{dict_ptr=atoms}(key=key_new, new_value=cast(atom_new, felt));
    dict_write{dict_ptr=atoms}(key=key, new_value=0);
    return (atoms_new=atoms);
}

// @notice Populates the faucet
// @param faucet The atom faucet
// @param atoms The dictionary of atoms
func populate_faucet{range_check_ptr}(faucet: AtomFaucetState, atoms: DictAccess*) -> (
    atoms: DictAccess*
) {
    alloc_locals;
    tempvar key = faucet.index.x * ns_dict.MULTIPLIER + faucet.index.y;
    let (is_full) = dict_read{dict_ptr=atoms}(key);
    if (is_full == 0) {
        tempvar atom: AtomState* = new AtomState(
            faucet.type, ns_atoms.FREE, Grid(faucet.index.x, faucet.index.y), 0
            );
        tempvar value = cast(atom, felt);
        dict_write{dict_ptr=atoms}(key=key, new_value=value);
        return (atoms=atoms);
    }
    return (atoms=atoms);
}

// @notice Checks the position is free of atoms
// @param pos The position on the board
// @param atoms The dictionary of atoms
// @return 1 if the position is free of atoms, 0 otherwise
func check_grid_free{range_check_ptr}(pos: Grid, atoms: DictAccess*) -> (
    atoms_new: DictAccess*, is_free: felt
) {
    tempvar key = pos.x * ns_dict.MULTIPLIER + pos.y;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    if (ptr == 0) {
        return (atoms_new=atoms, is_free=1);
    }
    return (atoms_new=atoms, is_free=0);
}

// @notice Checks the position is filled with an atom
// @param pos The position on the board
// @param atoms The dictionary of atoms
// @return 1 if the position is filled with an atom, 0 otherwise
func check_grid_filled{range_check_ptr}(pos: Grid, atoms: DictAccess*) -> (
    atoms_new: DictAccess*, is_filled: felt
) {
    tempvar key = pos.x * ns_dict.MULTIPLIER + pos.y;
    let (ptr) = dict_read{dict_ptr=atoms}(key=key);
    if (ptr == 0) {
        return (atoms_new=atoms, is_filled=0);
    }
    return (atoms_new=atoms, is_filled=1);
}
