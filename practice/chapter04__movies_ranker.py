import os
import random

movies = [
        {"name": "The Dark Knight", "year": 2008, "rating": "9"},
        {"name": "Kaili Blues", "year": 2015, "rating": "7.3"},
        {"name": "The Shawshank Redemption", "year": 1994, "rating": "9.3"},
        {"name": "Citizen Kane", "year": 1941, "rating": "8.3"}
    ]

all_sorting_types = ['name', 'rating', 'year', 'random']


class Movie:
    def __init__(self, name:str, year:int, rating:str) -> None:
        self.name = name
        self.year = year
        self.rating = rating

    @property
    def rank(self):
        """
        rank 的 Docstring
        按照评分对电影分级：
        - S: 8.5分 及以上
        - A: 8.0 - 8.5分
        - B: 7.0 - 8.0分
        - C: 6.0 - 7.0分
        - D: 6.0分 以下
        :param self: Movie instance
        """
        rating_num = float(self.rating)
        if rating_num >= 8.5:
            return 'S'
        elif rating_num >= 8.0:
            return 'A'
        elif rating_num >= 7.0:
            return 'B'
        elif rating_num >= 6.0:
            return 'C'
        else:
            return 'D'


def get_sorted_movies(movies, sorting_type):
    """对电影列表进行排序并返回
    :param movies: Movie 对象列表
    :param sorting_type: 排序选项，可选值
        name（名称）、rating（评分）、year（年份）、random（随机乱序）
    """
    if sorting_type == 'name':
        sorted_movies = sorted(movies, key=lambda movie: movie.name.lower())
    elif sorting_type == 'rating':
        sorted_movies = sorted(
            movies, key=lambda movie: float(movie.rating), reverse=True
        )
    elif sorting_type == 'year':
        sorted_movies = sorted(
            movies, key=lambda movie: movie.year, reverse=True
        )
    elif sorting_type == 'random':
        sorted_movies = sorted(movies, key=lambda movie: random.random())
    else:
        raise RuntimeError(f'Unknown sorting type: {sorting_type}')
    return sorted_movies


def main():
    # 接收用户输入的排序选项
    sorting_type = input('Please input sorting type: ')
    if sorting_type not in all_sorting_types:
        print(
            'Sorry, "{}" is not a valid sorting type, please choose from '
            '"{}", exit now'.format(
                sorting_type,
                '/'.join(all_sorting_types),
            )
        )
        return

    # 初始化电影数据对象
    movie_items = []
    for movie_json in movies:
        movie = Movie(**movie_json)
        movie_items.append(movie)

    # 排序并输出电影列表
    sorted_movies = get_sorted_movies(movie_items, sorting_type)
    for movie in sorted_movies:
        print(
            f'- [{movie.rank}] {movie.name}({movie.year}) | rating: {movie.rating}'
        )

if __name__ == "__main__":
    main()