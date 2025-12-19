def add_str(in_func_obj: str) -> None:
    print(f'In add [before]: in_func_obj = "{in_func_obj}"')
    in_func_obj += ' suffix'
    print(f'In add [after]: in_func_obj = "{in_func_obj}"')

orig_obj = 'foo' # Point is here, strings are immutable
print(f'Outside [before]: orig_obj = "{orig_obj}"')
add_str(orig_obj)
print(f'Outside [after]: orig_obj = "{orig_obj}"')

def add_list(in_func_obj: list) -> None:
    print(f'In add [before]: in_func_obj = {in_func_obj}')
    in_func_obj.append('baz')
    print(f'In add [after]: in_func_obj = {in_func_obj}')
          
origin_obj = ['foo','bar']
print(f'Outside [before]: origin_obj = {origin_obj}')
add_list(origin_obj)
print(f'Outside [after]: origin_obj = {origin_obj}')