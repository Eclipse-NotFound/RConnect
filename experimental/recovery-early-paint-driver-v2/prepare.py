"""Reuse the immutable v1 source/build recipe with explicitly verified v2 host pins."""
from binding import V1,KIND,load,verify_tools,preparation_bindings

def main():
    verify_tools()
    recipe=load('frozen_paint_driver_v1_prepare',V1/'prepare.py')
    # Keep the frozen source directory and original recipe; no copied implementation.
    recipe.HERE=V1
    recipe.KIND=KIND
    recipe.verify_tools=preparation_bindings
    recipe.main()

if __name__=='__main__':main()
