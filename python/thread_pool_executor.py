import time
from concurrent.futures import ThreadPoolExecutor, as_completed


def plus_num(*num):
    _sum = 0
    for i in range(0, len(num)):
        _sum += num[i]
        print('sleep for 1sec, num={} current={} sum={}'.format(num, num[i], _sum))
        time.sleep(1)
    return _sum

def async_plus_num(*num):
    worker = 2
    with ThreadPoolExecutor(max_workers=worker) as  executor:
        tasks = []
        step = int(len(num) / worker)
        for i in range(0, worker):
            if i +  1 == worker:
                tasks.append(executor.submit(plus_num, *num[i*step:len(num)]))
                continue
            tasks.append(executor.submit(plus_num, *num[i*step:i+step]))
        _sum = 0
        for task in as_completed(tasks):
            ret = task.result()
            _sum += ret
            print('now get result {}, sum is {}'.format(num, ret, _sum))
        return _sum
    return -1

def async_async_plus_num(*num):
    worker = 2
    with ThreadPoolExecutor(max_workers=worker) as  executor:
        tasks = []
        step = int(len(num) / worker)
        for i in range(0, worker):
            if i +  1 == worker:
                tasks.append(executor.submit(async_plus_num, *num[i*step:len(num)]))
                continue
            tasks.append(executor.submit(async_plus_num, *num[i*step:i+step]))
        _sum = 0
        for task in as_completed(tasks):
            try:
                ret = task.result()
                _sum += ret
                print('now get result {}, sum is {}'.format(num, ret, _sum))
            except Exception as e:
                print(e)
        return _sum
    return -1

if __name__ == '__main__':
    print(async_async_plus_num(*list(range(1, 43))))
