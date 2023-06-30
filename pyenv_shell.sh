export VIRTUAL_ENV_DISABLE_PROMPT=1
export PYENV_ROOT=/pyenv
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
