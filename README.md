# Mountain Car

The car is moving in the mountain described by the curve y = sin(3 * x). It is drawn for the interval x[-1.2,0.5]. The car starts randomly between [-0.6,-0.4] with zero velocity which may range from [-0.7, 0.7]. Each time step the reward is -1 until the goal on the right(0.5) is reached. When hitting on the left(-1.2) the car is reset to zero speed. The actions on each time step are: full throttle forward, full reverse and no throttle with values [-1,0,1]. Each time step the position and speed are updated by the rules:

Position = Position + Speed

Speed = Speed + 0.001 * Action - 0.0025 * cos(3 * Position)

# Differential Semi-Gradient SARSA


![](Fig10_1_MountainCar_Movement_Episode9000.gif)




# Function Approximation: Mountain Car & Access Control

<b>Chapter 10: Reinforcement Learning: An Introduction(2nd edition) by Sutton &amp; Barto</b>

This is reporoduction of figures from the the book. I have some inconsistencies with Tile Coding as you can see on Figure 10.2 - the Alpha values are in the exact opposite order compared to the book. Alpha 0.10 has the best performance, followed by 0.2 and Alpha 0.5 being the worst. I am not sure why - I use my own implementation of 8-Tile Coding. The Position-Veloicity state space is divided each by 8 tiles, displacement vector is (3,1) for each of the 8 tilings. Bitmap saving is implemented in pure Lua and is very slow!



Following are the images from Fig 10.1: State-Action Value-Function learning

Episode 1, Step 428:
![](MountainCar/Fig10_1_MountainCar_Episode1_00428.bmp)

At the end of Episode 1:
![](MountainCar/Fig10_1_MountainCar_00001.bmp)

Episode 12:
![](MountainCar/Fig10_1_MountainCar_00012.bmp)

Episode 104:
![](MountainCar/Fig10_1_MountainCar_00104.bmp)

Episode 1000:
![](MountainCar/Fig10_1_MountainCar_01000.bmp)

Episode 9000:
![](MountainCar/Fig10_1_MountainCar_09000.bmp)

Here's the policy learning animation during Episode 1(you can see the learned policy after 9000 episodes at the top of this document):
![](Fig10_1_MountainCar_Movement_Episode1.gif)



Figure 10.2: This is comparison of performance for Alphas 0.1, 0.2 and 0.5 during the first 500 episodes and averaged over 100 runs on a log scale for episode length. Note that for me they are in reversed order for what is shown on the book:
![](MountainCar/Fig10_2_MountainCar_Compare.bmp)



Figure 10.3: Comparison of the n-Step Differential Semi-Gradient SARSA for n=1(Alpha=0.5) and n=3(Alpha=0.3):
![](MountainCar/Fig10_3_MountainCar_Compare_NStep.bmp)



Figure 10.4: Comparison of the n-Step Differential Semi-Gradient SARSA for various n values plotted as different functions of Alpha as parameter against average first 50 episodes length(and also averaged for 100 runs). The episode length is on log scale:
![](MountainCar/Fig10_4_MountainCar_N_VS_Alpha.bmp)







# Access Control

Following are the figures for Access Control of unlimited queue of users with priorities 1, 2, 3 and 4 each giving a reward 1, 2, 4 and 8(if served) where the the first user on the queue is either served or rejected. There are 10 servers and each time step a busy server is becoming available with probability 0.06. If there are no free servers the user is always rejected. Being rejected gives reward 0.

![](AccessControl/Fig10_5_AccessControl_Policy.bmp)

This is the value learned for best action when there are 0-10 free servers available:

![](AccessControl/Fig10_5_AccessControl_VF.bmp)
