echo "Running Terraform commands to apply changes..."
terraform destroy -auto-approve
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
echo "Terraform commands completed."