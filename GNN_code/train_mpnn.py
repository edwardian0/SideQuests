    
# train_mpnn.py
from preprocessing.fetch_smiles import resolve_smiles_by_cas_interactive
from preprocessing.smiles_to_graph import batch_from_csv
from models.train import train_model

if __name__ == "__main__":
    # Produce SMILES strings from CAS numbers
    df = resolve_smiles_by_cas_interactive("data/raw/Ozkan_data_2024.xlsx", "data/processed/input.csv")
    
    # Convert smiles strings in the CSV file to a list of PyTorch graphs
    graph_list = batch_from_csv("data/processed/input.csv")
    
    # Train the model on the graph list
    train_model(graph_list)
