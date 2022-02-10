# [Action name] action

[Overview]

Note: 
[Any important notes.]

## Action input parameters

| Parameter                      | Description                                              | required |  comment                                    |
| ------------------------------ | :------------------------------------------------------- | -------- | ------------------------------------------- |
| [input parameter 1             | [Small description about parameter]                      | [yes/no] | [Any addition comments]                     |     |
| [input parameter 2]            | [Small description about parameter]                      | [yes/no] | [Any addition comments]                     |


Specify
## Action output parameters

n/a

## Usages

### Invoke the action on pull request to master branch
For Example: its sample example, please updated below same as implemented with input and run.

```yml
name: [Action name]
on:
  pull_request:
    branches:
      - [main]
        
jobs:
  [input tag1]:
    runs-on: [self-hosted, research]
    name: [Some name]
    steps:
      - name: [Step Name]
        id: [ID text]
        uses: philips-software/[action name]@[action version]
```
