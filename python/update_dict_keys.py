#! /usr/bin/env python3

import copy
import unittest

def replace_percentage_symbol(val):
    return val.replace('%', 'pct') if isinstance(val, str) else val

def update_keys(orig):
    if not isinstance(orig, (dict, list)):
        return orig
    cp = copy.deepcopy(orig)
    if isinstance(orig, dict):
        for k, v in orig.items():
            _new = replace_percentage_symbol(k)
            if _new != k:
                cp[_new] = v
                cp.pop(k)
            if isinstance(v, (dict, list)):
                cp[_new] = update_keys(v)

    if isinstance(orig, list):
        for i in range(0, len(orig)):
            cp[i] = update_keys(orig[i])

    return cp



class TestUpdatingDictKeys(unittest.TestCase):
    def __init__(self, _in, expect, desc=''):
        super().__init__(methodName='test_update')
        self._in = _in
        self.expect = expect
        self.desc = desc

    def test_update(self):
        print(self.shortDescription())
        self.assertEqual(update_keys(self._in), self.expect)

    def shortDescription(self):
        return 'update_keys {}'.format(self.desc)


def gen_test_suite():
    tests = [
        {
            'input': {'key_1%': ''},
            'expect': {'key_1pct': ''},
            'desc': 'input is dict'
        },
        {
            'input': [{'key_1%': ''}, {'key_2%': ''}],
            'expect': [{'key_1pct': ''}, {'key_2pct': ''}],
            'desc': 'input is list'
        },
        {
            'input': {'key_1%': {'key_2%': [{'key_3%': ''}, {'key_4': ''}]}},
            'expect': {'key_1pct': {'key_2pct': [{'key_3pct': ''}, {'key_4': ''}]}},
            'desc': 'input is mix of dict and list'
        },
        {
            'input': 'abc',
            'expect': 'abc',
            'desc': 'input is string'
        },
        {
            'input': 123,
            'expect': 123,
            'desc': 'input is integer'
        },
        {
            'input': [],
            'expect': [],
            'desc': 'input is empty list'
        },
        {
            'input': {},
            'expect': {},
            'desc': 'input is empty dict'
        },
        {
            'input': None,
            'expect': None,
            'desc': 'input is None'
        },
    ]
    return unittest.TestSuite([TestUpdatingDictKeys(x.get('input'), x.get('expect'), x.get('desc')) for x in tests])

if __name__ == '__main__':
    runner = unittest.TextTestRunner()
    runner.run(gen_test_suite())
