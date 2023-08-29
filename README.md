# multi_tz

## Template

`multi_tz` accepts a format argument where you provide the desired template.
Between `{}` provide the target timezone. Supported timezones are   `PT`,`CT`,`ET`,`BUE` and `BCN`.

```
> multi_tz -t "{BCN} | {BUE} | {ET} | {CT}"
20:32:08 | 15:32 | 14:32 | 13:32
```

### zsh + powerlevel10k

Add the following function to `~/.p10k.zsh`.
```
function prompt_multi_tz(){
  content=$(multi_tz -t $HERE_GOES_YOUR_TEMPLATE)
  p10k segment -f 6 -i 🌎 -t ${content//\%/%%}
}
```

Under `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`, comment out `time` and add `multi_tz`

```
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    ... 
    # time                    # current time
    multi_tz
    ...
)
```