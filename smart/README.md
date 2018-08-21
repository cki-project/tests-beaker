# Smart testing tool

## 1. Structure

        smart
        ├── README.md
        ├── sample
        │   ├── layout
        │   │   ├── default
        │   │   │   ├── patterns.json
        │   │   │   └── template.xml
        │   │   └── layout.json
        │   └── patch
        │       └── foo.patch
        └── utils
            └── python
                ├── Makefile
                ├── smart.py
                ├── smart_testcases.py
                └── smart_xmlpieces.py

## 2. Sample Layout

We define layout via JSON file, the top level layout is
`sample/layout/layout.json`.

In the top level layout, we define a dictionary, and every key/value presents
a pattern entry, e.g.

```JSON
        {
            "default": "default/patterns.json",
            "NULL": null
        }
```

In pattern entry, we defined `patterns` and `cases`. `patterns` is a list
whose element contains `pattern` and `case`, note that `pattern` is a regular
expression. `cases` is also a list, whose element contains `case`, `template`
and `handler`, note that `handler` can be `null` or a script to handle
xml `template`. e.g.

```JSON
        {
            ...<snip>...
            "patterns": [
                {
                    "pattern": ".*",
                    "case": "default/foo"
                }
            ],
            "cases": [
                {
                    "case": "default/foo",
                    "template": "default/template.xml",
                    "handler": null
                }
            ],
            ...<snip>...
        }
```

In `sample/layout/default/patterns.json`, we defined a case `default/foo`
and its pattern is `.*`, which means it matches any string. That is, the case
`default/foo` is always picked to verify a patch.


## 3. Utilities

There are two utilities in the smart testing tool, one is
`utils/python/smart_testcases.py`, the other is
`utils/python/smart_xmlpieces.py`.

+ `utils/python/smart.py`: library shared by utilities
+ `utils/python/smart_testcases.py`: get test cases according to a patch file
+ `utils/python/smart_xmlpieces.py`: get xml pieces according to test cases

## 4. Usage

### 4.1 Get test cases according to a patch file
e.g.
+ `cd utils/python`
+ `make`
+ `./smart_testcases -l ../../sample/layout/layout.json ../../sample/patch/foo.patch`

OR
+ `./smart_testcases -l ../../sample/layout/layout.json -o /tmp/cases.out ../../sample/patch/foo.patch`

### 4.2 Get xml pieces according to test cases
e.g.
+ `cd utils/python`
+ `make`
+ `./smart_xmlpieces -l ../../sample/layout/layout.json /tmp/cases.out`

OR
+ `./smart_xmlpieces -l ../../sample/layout/layout.json -o /tmp/xml.out /tmp/cases.out`

**NOTE:** Both of the two utilities support debugging mode via option '-d'.
e.g.
+ `./smart_testcases `**`-d`**` -l ../../sample/layout/layout.json ../../sample/patch/foo.patch`
