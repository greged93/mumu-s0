%lang starknet

from starkware.cairo.common.dict import dict_write, dict_read, dict_update
from starkware.cairo.common.dict_access import DictAccess

from contracts.simulator.grid import Grid, GRID_SIZE
from contracts.simulator.constants import ns_dict

func check_uniqueness{range_check_ptr}(
    operators_len: felt, operators: Grid*, dict: DictAccess*
) -> (dict: DictAccess*) {
    if (operators_len == 0) {
        return (dict=dict);
    }
    tempvar operator = [operators];
    tempvar key = operator.x * ns_dict.MULTIPLIER + operator.y;
    let (value) = dict_read{dict_ptr=dict}(key=key);

    with_attr error_message("overlapping operators") {
        assert value = 0;
    }
    dict_write{dict_ptr=dict}(key=key, new_value=1);
    return check_uniqueness(operators_len - 1, operators + GRID_SIZE, dict);
}
