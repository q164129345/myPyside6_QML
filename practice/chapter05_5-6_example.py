import os


def input_a_number():
    while True:
        number = input("Please input a number:(0 - 100)")
        if not number:
            print('Input can not be empty!')
            continue
        if not number.isdigit():
            print('Input must be a number!')
            continue
        if not (0 <= int(number) <= 100):
            print('Input number must be in range 0 - 100!')
            continue
        number = int(number)
        break
    print(f'Your number is {number}')




def main():
    input_a_number()


if __name__ == '__main__':
    main()