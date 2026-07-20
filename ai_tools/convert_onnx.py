import subprocess
import argparse
import sys
import os

def convert_model(model_id: str, output_dir: str):
    print(f"🚀 Début de la conversion du modèle : {model_id}")
    print("Cette opération va télécharger le modèle, le convertir en ONNX, et appliquer une quantisation INT8...")
    
    os.makedirs(output_dir, exist_ok=True)
    
    command = [
        "optimum-cli", "export", "onnx",
        "--model", model_id,
        "--task", "text2text-generation",
        "--optimize", "O2",
        "--quantize", "dynamic",
        output_dir
    ]
    
    try:
        subprocess.run(command, check=True)
        print(f"\n✅ Succès ! Modèle converti et sauvegardé dans : {output_dir}")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Erreur lors de la conversion : {e}")
        sys.exit(1)
    except FileNotFoundError:
        print("\n❌ L'outil 'optimum-cli' est introuvable.")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convertir un modèle de traduction HuggingFace en ONNX INT8.")
    parser.add_argument("--model", type=str, default="Helsinki-NLP/opus-mt-fr-en", help="ID du modèle HuggingFace")
    parser.add_argument("--output", type=str, default="./models_onnx/fr-en", help="Dossier de sortie")
    
    args = parser.parse_args()
    convert_model(args.model, args.output)
