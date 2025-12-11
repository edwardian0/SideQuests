import torch
from torch_geometric.nn import GATConv, global_mean_pool
from torch.nn import Sequential, Linear, ReLU, Dropout
from torch.nn import MSELoss
from torch_geometric.loader import DataLoader
from sklearn.metrics import r2_score, mean_squared_error
import matplotlib.pyplot as plt
import numpy as np

class GATModel(torch.nn.Module):
    def __init__(self, in_channels, hidden_dim, out_dim=1, dropout_rate=0.2):
        super().__init__()

        self.conv1 = GATConv(in_channels, hidden_dim, heads=2, concat=False)
        self.ffnn = Sequential(
            Linear(hidden_dim, hidden_dim),
            ReLU(),
            Dropout(dropout_rate),
            Linear(hidden_dim, out_dim)
        )

    def forward(self, x, edge_index, batch):
        x = self.conv1(x, edge_index)
        x = torch.relu(x)
        x = global_mean_pool(x, batch)
        return self.ffnn(x)


def train_gat_model(dataloader, model, lr=1e-3, epochs=300):
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = MSELoss()

    model.train()
    for epoch in range(epochs):
        total_loss = 0
        for batch in dataloader:
            optimizer.zero_grad()
            out = model(batch.x, batch.edge_index, batch.batch).squeeze()
            target = batch.y.squeeze()

            assert out.shape == target.shape, f"{out.shape=} vs {target.shape=}"
            loss = loss_fn(out, target)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        print(f"Epoch {epoch+1}, Loss: {total_loss:.4f}")
    
    return model


def plot_predictionsGAT(model, loader):
    """
    Function to plot predictions vs actual values without scaling.
    """
    all_preds = [] 
    all_targets = []

    model.eval()
    with torch.no_grad():
        for batch in loader:
            preds = model(batch.x, batch.edge_index, batch.batch)
            # all_preds.append(preds.squeeze())
            # all_targets.append(batch.y.squeeze())
            all_preds.append(preds.view(-1))     # ensures [N]
            all_targets.append(batch.y.view(-1)) # ensures [N]

    all_preds = torch.cat(all_preds).cpu().numpy()
    all_targets = torch.cat(all_targets).cpu().numpy()

    r2 = r2_score(all_targets, all_preds)
    rmse = np.sqrt(mean_squared_error(all_targets, all_preds))

    print(f"R² score: {r2:.3f}")
    print(f"RMSE: {rmse:.3f}")

    plt.figure(figsize=(6, 6))
    plt.scatter(all_targets, all_preds, alpha=0.7)
    plt.plot([all_targets.min(), all_targets.max()], 
             [all_targets.min(), all_targets.max()], 'r--')
    plt.xlabel("Actual")
    plt.ylabel("Predicted")
    plt.title("Predicted vs. Actual - GAT Model (Batched)")
    plt.grid(True)
    plt.tight_layout()
    plt.show()
    