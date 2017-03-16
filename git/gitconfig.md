
## Commit at another date/time

Set the variable `$GIT_DATE_DELTA` to commit at another date/time

This parameter is the delta with the current time datetime.

Accepted values:

```bash
[+|-]val[ymwdHMS]]
```

### Sample usage

```bash
➜  vim-simulator git:(master) ✗ date
Thu Mar 16 18:50:50 GMT 2017
➜  vim-simulator git:(master) ✗ date -v$GIT_DATE_DELTA
date: option requires an argument -- v
usage: date [-jnu] [-d dst] [-r seconds] [-t west] [-v[+|-]val[ymwdHMS]] ...
            [-f fmt date | [[[mm]dd]HH]MM[[cc]yy][.ss]] [+format]
➜  vim-simulator git:(master) ✗ export GIT_DATE_DELTA="+5H"
➜  vim-simulator git:(master) ✗ date -v$GIT_DATE_DELTA
Thu Mar 16 23:50:01 GMT 2017
```
