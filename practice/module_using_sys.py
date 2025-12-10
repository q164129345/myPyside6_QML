import sys

def main():
    print("The command line arguments are:")
    # sys.argv is the list of command line arguments
    # run shell: python ./module_using_sys.py we are arguments 
    # sys.argv[0] = 'we'
    # sys.argv[1] = 'are'
    # sys.argv[2] = 'arguments'
    for arg in sys.argv:
        print(arg)
    print("\n\nThe PYTHONPATH is", sys.path, "\n")



if __name__ == "__main__":
    main()




