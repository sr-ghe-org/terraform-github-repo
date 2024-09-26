# vim: filetype=terraform syntax=terraform softtabstop=2 tabstop=2 shiftwidth=2 fileencoding=utf-8 commentstring=#%s expandtab
# code: language=terraform insertSpaces=true tabSize=2

/*
  DO NOT DECLARE PROVIDERS IN MODULES.

  This file is here to remind users that no providers are declared in Private Module Registry modules.
  
  Modules should inherit providers from the workspace (sometimes called the "root module").

  Instead of declaring providers, declare provider version requirements in the `terraform`
  block in the versions.tf file.
*/
