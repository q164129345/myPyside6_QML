import heapq

class PriorityQueue:
    def __init__(self):
        self._queue = []
        self._index = 0

    def push(self, item, priority):
        # 使用负优先级实现最大堆效果
        heapq.heappush(self._queue, (-priority, self._index, item))
        print(self._queue)
        print((-priority, self._index, item))
        self._index += 1

    def pop(self):
        return heapq.heappop(self._queue)[-1]

class Item:
    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return 'Item({!r})'.format(self.name)


if __name__ == '__main__':
    pq = PriorityQueue()
    pq.push(Item('task1'), 1)
    pq.push(Item('task2'), 5)
    pq.push(Item('task3'), 3)

    print(pq.pop())
    print(pq.pop())