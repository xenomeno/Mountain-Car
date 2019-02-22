# Mountain-Car

# Differential Semi-Gradient SARSA

# Function Approximation: Mountain Car & Access Control

<b>Chapter 10: Reinforcement Learning: An Introduction(2nd edition) by Sutton &amp; Barto</b>

This is reporoduction of figures from the book. I have some inconsistencies with Tile Coding as you can see on Figure 10.2 - the Alpha values are in the exact opposite border compared to the book. Alpha 0.10 has the best performance, followed by 0.2 and Alpha 0.5 being the worst. I am not sure why - I use my own implementation of 8-Tile Coding. The Position-Veloicity state space is divided each by 8 tiles, displacement vector is (3,1) for each of the 8 tilings. Bitmap is implemented in pure Lua and is very slow!

Approximation by Monte Carlo using State Aggregation:

![](Fig10_2_MountainCar_Compare.bmp)

Approximation by TD(0) using State Aggregation:

![](RandomWalk1000/RandomWalk1000_TD(0).bmp)

Comparison of TD algorithms with different step size N. This picture is with ACTIONS to left and right up to 50 states:

![](RandomWalk1000/RandomWalk1000_TDn.bmp)

This one is with ACTIONS to left and right up to 100 states

![](RandomWalk1000/RandomWalk1000_TDn_100_ACTIONS.bmp)

Comparison of basises during learning - Polynomial VS Fourier:

![](RandomWalk1000/RandomWalk1000_Basis.bmp)

Comparison of Tile coding using 50 tiles VS 1-tile/no-tiling(which is equivalent to State Aggregation). Note that I run it for 10,000 episodes since 5,000 for me were not enough to outpeform the no-tiling:

![](RandomWalk1000/RandomWalk1000_Tiling.bmp)

