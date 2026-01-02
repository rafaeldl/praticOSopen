#!/bin/bash

# Script para configurar credenciais do Firebase Admin SDK

echo "════════════════════════════════════════════════════════════"
echo "  CONFIGURAÇÃO DE CREDENCIAIS - Firebase Admin SDK"
echo "════════════════════════════════════════════════════════════"
echo ""

# Verificar se já está configurado
if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  echo "✓ Variável GOOGLE_APPLICATION_CREDENTIALS já está configurada:"
  echo "  $GOOGLE_APPLICATION_CREDENTIALS"
  echo ""
  read -p "Deseja alterar? (s/n): " change
  if [ "$change" != "s" ]; then
    exit 0
  fi
fi

echo "Escolha uma opção:"
echo ""
echo "1. Usar arquivo de Service Account (RECOMENDADO)"
echo "2. Usar gcloud CLI (gcloud auth application-default login)"
echo "3. Cancelar"
echo ""
read -p "Opção [1-3]: " option

case $option in
  1)
    echo ""
    echo "Para obter o arquivo de Service Account:"
    echo "1. Acesse: https://console.firebase.google.com/project/praticos/settings/serviceaccounts/adminsdk"
    echo "2. Clique em 'Gerar nova chave privada'"
    echo "3. Salve o arquivo JSON"
    echo ""
    read -p "Digite o caminho completo do arquivo JSON: " filepath
    
    if [ ! -f "$filepath" ]; then
      echo "❌ Erro: Arquivo não encontrado: $filepath"
      exit 1
    fi
    
    # Converter para caminho absoluto
    filepath=$(cd "$(dirname "$filepath")" && pwd)/$(basename "$filepath")
    
    echo ""
    echo "✓ Arquivo encontrado: $filepath"
    echo ""
    echo "Para usar esta configuração, execute:"
    echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"$filepath\""
    echo "  npm run refresh-claims"
    echo ""
    echo "Ou adicione ao seu ~/.zshrc ou ~/.bashrc:"
    echo "  export GOOGLE_APPLICATION_CREDENTIALS=\"$filepath\""
    echo ""
    read -p "Deseja adicionar ao ~/.zshrc agora? (s/n): " add_to_zshrc
    
    if [ "$add_to_zshrc" == "s" ]; then
      echo "" >> ~/.zshrc
      echo "# Firebase Admin SDK Credentials" >> ~/.zshrc
      echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$filepath\"" >> ~/.zshrc
      echo "✓ Adicionado ao ~/.zshrc"
      echo "Execute: source ~/.zshrc"
    fi
    ;;
    
  2)
    echo ""
    echo "Executando: gcloud auth application-default login"
    gcloud auth application-default login
    if [ $? -eq 0 ]; then
      echo ""
      echo "✓ Autenticação concluída!"
      echo "Agora você pode executar os scripts normalmente."
    else
      echo ""
      echo "❌ Erro na autenticação. Verifique se o gcloud está instalado."
      exit 1
    fi
    ;;
    
  3)
    echo "Cancelado."
    exit 0
    ;;
    
  *)
    echo "Opção inválida."
    exit 1
    ;;
esac

