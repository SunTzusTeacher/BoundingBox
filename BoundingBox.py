from sklearn.cluster import DBSCAN
import json
from itertools import combinations
from geopy.distance import geodesic

input_file = "export.geojson"
output_file = "output.txt"
threshold = 0.005  # Adjust the threshold as needed

# Load GeoJSON data
with open(input_file, "r") as file:
    data = json.load(file)

# Extract coordinates
all_coordinates = []
for feature in data["features"]:
    geometry = feature.get("geometry")
    if geometry and geometry["type"] == "LineString":
        coordinates = geometry.get("coordinates")
        if coordinates:
            all_coordinates.extend(coordinates)

# Perform clustering using DBSCAN
dbscan = DBSCAN(eps=threshold, min_samples=2, metric='haversine')
clusters = dbscan.fit_predict(all_coordinates)

# Prepare clustered data
clustered_coordinates = {}
for idx, cluster_label in enumerate(clusters):
    if cluster_label not in clustered_coordinates:
        clustered_coordinates[cluster_label] = []
    clustered_coordinates[cluster_label].append(all_coordinates[idx])

# Find the two farthest coordinates within each cluster
farthest_coords_per_cluster = {}
for cluster_label, cluster_coords in clustered_coordinates.items():
    max_distance = 0
    farthest_pair = None
    if len(cluster_coords) > 1:  # Ensure there are at least 2 points in the cluster
        for pair in combinations(cluster_coords, 2):
            dist = geodesic(pair[0], pair[1]).meters
            if dist > max_distance:
                max_distance = dist
                farthest_pair = pair
    farthest_coords_per_cluster[cluster_label] = (farthest_pair, max_distance)

# Output the two farthest coordinates in each cluster
with open(output_file, "w") as outfile:
    for cluster_label, (farthest_pair, max_distance) in farthest_coords_per_cluster.items():
        outfile.write(f"Cluster {cluster_label}:\n")
        if farthest_pair:
            outfile.write(f"Farthest coordinates: {farthest_pair[0]} and {farthest_pair[1]}\n")
            outfile.write(f"Distance between them: {max_distance} meters\n\n")
        else:
            outfile.write("Not enough points in the cluster for distance calculation\n\n")
