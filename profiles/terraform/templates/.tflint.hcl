# tflint для репозитория модуля (навык terraform-conventions, dev/check-terraform.sh).
# Встроенный набор правил terraform: preset "all" — типы и описания переменных и outputs,
# стандартная структура модуля, нижние границы версий, имена в snake_case.
plugin "terraform" {
  enabled = true
  preset  = "all"
}
