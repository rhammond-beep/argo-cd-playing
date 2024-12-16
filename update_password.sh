#!/bin/bash

# if you are managing users as the admin user, <current-user-password> should be the current admin password.
argocd account update-password \
  --account rupert_hammond \
  --current-password ${ADMIN_PASSWORD} \
  --new-password ${NEW_PASSWORD}
