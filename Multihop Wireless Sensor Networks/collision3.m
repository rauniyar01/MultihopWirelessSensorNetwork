clc;
clear all;
close all;

numberOfChildNodes = 0;
numberOfCollisions = 0;
xCoordinateMatrix = zeros(5,20);
yCoordinateMatrix = zeros(5,20);


for loopCounter = 1:5
numberOfChildNodes = 0;
addToVector = 1;
xChildNodes = [];
yChildNodes = [];
while (numberOfChildNodes < 20)
    if(isempty(xChildNodes))
        xCoordinate = randi(100,1,1);
        yCoordinate = randi(100,1,1);
        while(xCoordinate == 50 && yCoordinate == 50) 
            xCoordinate = randi(100,1,1);
            yCoordinate = randi(100,1,1);
        end
        distanceFromRoot = (xCoordinate - 50)^2 + (yCoordinate - 50)^2;
        while (distanceFromRoot > 49^2)
            xCoordinate = randi(100,1,1);
            yCoordinate = randi(100,1,1);
            while(xCoordinate == 50 && yCoordinate == 50) 
                xCoordinate = randi(100,1,1);
                yCoordinate = randi(100,1,1);
            end
            distanceFromRoot = (xCoordinate - 50)^2 + (yCoordinate - 50)^2;
        end
        xChildNodes = [xChildNodes xCoordinate];
        yChildNodes = [yChildNodes yCoordinate];
        numberOfChildNodes = numberOfChildNodes + 1;
        
    else
        xCoordinate = randi(100,1,1);
        yCoordinate = randi(100,1,1);
        while(xCoordinate == 50 && yCoordinate == 50) 
            xCoordinate = randi(100,1,1);
            yCoordinate = randi(100,1,1);
        end
        distanceFromRoot = (xCoordinate - 50)^2 + (yCoordinate - 50)^2;
        while (distanceFromRoot > 49^2)
            xCoordinate = randi(100,1,1);
            yCoordinate = randi(100,1,1);
            while(xCoordinate == 50 && yCoordinate == 50) 
                xCoordinate = randi(100,1,1);
                yCoordinate = randi(100,1,1);
            end
            distanceFromRoot = (xCoordinate - 50)^2 + (yCoordinate - 50)^2;
        end
        
        for i = 1:length(xChildNodes)
            if(xChildNodes(i) == xCoordinate && yChildNodes(i) == yCoordinate)
                addToVector = 0;
                break;
            end
        end
        if(addToVector == 1 && distanceFromRoot < 49^2)
            xChildNodes = [xChildNodes xCoordinate];
            yChildNodes = [yChildNodes yCoordinate];
        else
            while (addToVector == 0 && distanceFromRoot > 49^2)
                addToVector = 1;
                xCoordinate = randi(100,1,1);
                yCoordinate = randi(100,1,1);
                for i = 1:length(xChildNodes)
                    if(xChildNodes(i) == xCoordinate && yChildNodes(i) == yCoordinate)
                        addToVector = 0;
                    break;
                    end
                end
                distanceFromRoot = (xCoordinate - 50)^2 + (yCoordinate - 50)^2;
            end
            xChildNodes = [xChildNodes xCoordinate];
            yChildNodes = [yChildNodes yCoordinate];
        end
        numberOfChildNodes = numberOfChildNodes + 1;
    end
end
xCoordinateMatrix(loopCounter,:) = xChildNodes;
yCoordinateMatrix(loopCounter,:) = yChildNodes;
% numberOfTransmitters = randi(5,1,1);
% 
% xTransmitters = [];
% yTransmitters = [];
% 
% transmitterCount = 0;
% addToTransmittersVector = 1;
% 
% while (transmitterCount < numberOfTransmitters)
%     i = randi(length(xChildNodes),1,1);
%     if(isempty(xTransmitters))
%         xTransmitters = [xTransmitters xChildNodes(i)];
%         yTransmitters = [yTransmitters yChildNodes(i)];
%     else
%         for j = 1:length(xTransmitters)
%             if(xTransmitters(j) == xChildNodes(i) && yTransmitters(j) == yChildNodes(i))
%                 addToTransmitterVector = 0;
%                 break;
%             end
%         end
%         if(addToTransmittersVector == 1)
%             xTransmitters = [xTransmitters xChildNodes(i)];
%             yTransmitters = [yTransmitters yChildNodes(i)];
%         else
%             while(addToTransmitterVector == 0)
%                 i = randi(length(xChildNodes),1,1);
%                 addToTransmitterVector = 1;
%                 for j = 1:length(xTransmitters)
%                      if(xTransmitters(j) == xChildNodes(i) && yTransmitters(j) == yChildNodes(i))
%                         addToTransmitterVector = 0;
%                         break;
%                      end
%                 end
%             end
%             xTransmitters = [xTransmitters xChildNodes(i)];
%             yTransmitters = [yTransmitters yChildNodes(i)];
%         end
%     end
%     transmitterCount = transmitterCount + 1;
% end
% 
% for i = 1:length(xTransmitters)
%    for j = i+1:length(xTransmitters)
%         distanceBetweenTransmitters = (xTransmitters(i) - xTransmitters(j))^2 + (yTransmitters(i) - yTransmitters(j))^2;
%         if(distanceBetweenTransmitters < 49^2)
%             numberOfCollisions = numberOfCollisions + 1;
%          end
%     end
% end

figure();
hold on;
scatter(xChildNodes,yChildNodes);
scatter([50],[50],'d','MarkerEdgeColor','r','MarkerFaceColor','r','LineWidth',1.5);
%scatter(xTransmitters,yTransmitters,'s','MarkerEdgeColor','r');
hold off;

end

xSingleChannelNetwork = zeros(1,100);
ySingleChannelNetwork = zeros(1,100);
numberOfClusterheads = 4;
addToClusterheadsVector = 1;
xClusterheads = [];
yClusterheads = [];
clusterheadCount = 0;

while (clusterheadCount < numberOfClusterheads)
    i = randi(length(xCoordinateMatrix(1,:)),1,1);
    if(isempty(xClusterheads))
        xClusterheads = [xClusterheads xCoordinateMatrix(1,i)];
        yClusterheads = [yClusterheads yCoordinateMatrix(1,i)];
    else
        for j = 1:length(xClusterheads)
            if(xClusterheads(j) == xCoordinateMatrix(1,i) && yClusterheads(j) == yCoordinateMatrix(1,i))
                addToClusterheadsVector = 0;
                break;
            end
        end
        if(addToClusterheadsVector == 1)
            xClusterheads = [xClusterheads xCoordinateMatrix(1,i)];
            yClusterheads = [yClusterheads yCoordinateMatrix(1,i)];
        else
            while(addToClusterheadsVector == 0)
                i = randi(length(xCoordinateMatrix(1,:)),1,1);
                addToClusterheadsVector = 1;
                for j = 1:length(xClusterheads)
                     if(xClusterheads(j) == xCoordinateMatrix(1,i) && yClusterheads(j) == yCoordinateMatrix(1,i))
                        addToClusterheadsVector = 0;
                        break;
                     end
                end
            end
            xClusterheads = [xClusterheads xCoordinateMatrix(1,i)];
            yClusterheads = [yClusterheads yCoordinateMatrix(1,i)];
        end
    end
    clusterheadCount = clusterheadCount + 1;
end

k = 0;
for j = 1:5
    for i = 1:length(xCoordinateMatrix(j,:))
        k = k+1;
        if(j==1)
            xSingleChannelNetwork(k) = (200 + (xCoordinateMatrix(j,i) - 50));
            ySingleChannelNetwork(k) = (200 + (yCoordinateMatrix(j,i) - 50));
        else
            xSingleChannelNetwork(k) = (200+(xClusterheads(j-1)-50) + (xCoordinateMatrix(j,i) - 50));
            ySingleChannelNetwork(k) = (200+(yClusterheads(j-1)-50) + (yCoordinateMatrix(j,i) - 50));
        end
    end
end

xSingleChannelNetwork = reshape(xSingleChannelNetwork,5,20);
ySingleChannelNetwork = reshape(ySingleChannelNetwork,5,20);
colors = ['r','b','c','m','g'];
figure();
hold on;
for i = 1:5
scatter(xSingleChannelNetwork(i,:),ySingleChannelNetwork(i,:),colors(i));
end
scatter([200],[200],'d','MarkerEdgeColor',colors(1),'MarkerFaceColor',colors(1),'LineWidth',1.5);
for i =1:4
scatter(xClusterheads(i) + 150,yClusterheads(i) + 150,'d','MarkerEdgeColor',colors(i+1),'MarkerFaceColor',colors(i+1),'LineWidth',1.5);
circle(xClusterheads(i)+150,yClusterheads(i)+150,49);
end

hold off;


numberOfCollisionsClusters = 0;
numberOfCollisionsSingleChannel = 0;
collisionClusters = zeros(1,80);
collisionClustersCheck = zeros(1,80);
xtransmitterMatrix = zeros(5,5);
collisionSingleChannel = zeros(1,80);
collisionSingleChannelCheck = zeros(1,80);
for loopCounter = 1:80
    numberOfCollisionsClusters = 0;
    numberOfCollisionsSingleChannel = 0;
    xTransmitterMatrix = zeros(5,5);
    yTransmitterMatrix = zeros(5,5);
    xSingleChannelTransmitter = zeros(1,25);
    ySingleChannelTransmitter = zeros(1,25);
    collisionClustersCheck = zeros(1,80);
    collisionSingleChannelCheck = zeros(1,80);
    for loopCounter2 = 1:5
     numberOfTransmitters = randi(5,1,1);

     xTransmitters = [];
     yTransmitters = [];

    transmitterCount = 0;
    addToTransmittersVector = 1;
    
    while (transmitterCount < numberOfTransmitters)
        i = randi(length(xCoordinateMatrix(loopCounter2,:)),1,1);
        if(isempty(xTransmitters))
            xTransmitters = [xTransmitters xCoordinateMatrix(loopCounter2,i)];
            yTransmitters = [yTransmitters yCoordinateMatrix(loopCounter2,i)];
        else
            for j = 1:length(xTransmitters)
                if(xTransmitters(j) == xCoordinateMatrix(loopCounter2,i) && yTransmitters(j) == yCoordinateMatrix(loopCounter2,i))
                    addToTransmitterVector = 0;
                    break;
                end
            end
            if(addToTransmittersVector == 1)
                xTransmitters = [xTransmitters xCoordinateMatrix(loopCounter2,i)];
                yTransmitters = [yTransmitters yCoordinateMatrix(loopCounter2,i)];
            else
                while(addToTransmitterVector == 0)
                    i = randi(length(xCoordinateMatrix(loopCounter2,:)),1,1);
                    addToTransmitterVector = 1;
                    for j = 1:length(xTransmitters)
                         if(xTransmitters(j) == xCoordinateMatrix(loopCounter2,i) && yTransmitters(j) == yCoordinateMatrix(loopCounter2,i))
                                addToTransmitterVector = 0;
                                break;
                         end
                    end
                end
                xTransmitters = [xTransmitters xCoordinateMatrix(loopCounter2,i)];
                yTransmitters = [yTransmitters yCoordinateMatrix(loopCounter2,i)];
            end
        end
        transmitterCount = transmitterCount + 1;
    end
    
    for i = 1:length(xTransmitters)
       for j = i+1:length(xTransmitters)
           if(xTransmitters(j) ~= 0 && yTransmitters(j) ~= 0)
                distanceBetweenTransmitters = (xTransmitters(i) - xTransmitters(j))^2 + (yTransmitters(i) - yTransmitters(j))^2;
                if(distanceBetweenTransmitters < 49^2)
                    collisionClustersCheck(i) = 1;
                    collisionClustersCheck(j) = 1;
                    numberOfCollisionsClusters = numberOfCollisionsClusters + 1;
                    break;
                end
           end
        end
    end
    
    numberOfCollisionsClusters = sum(collisionClustersCheck);
    collisionClusters(loopCounter) = collisionClusters(loopCounter) +numberOfCollisionsClusters;
    xTransmitterMatrix(loopCounter2,:) = [xTransmitters zeros(1,5-length(xTransmitters))];
    yTransmitterMatrix(loopCounter2,:) = [yTransmitters zeros(1,5-length(yTransmitters))];
    end
    k = 0;
    for j = 1:5
        for i = 1:length(xTransmitterMatrix(j,:))
            k = k+1;
            if(j==1)
                xSingleChannelTransmitter(k) = (200 + (xTransmitterMatrix(j,i) - 50));
                ySingleChannelTransmitter(k) = (200 + (yTransmitterMatrix(j,i) - 50));
            else
                xSingleChannelTransmitter(k) = (200+(xClusterheads(j-1)-50) + (xTransmitterMatrix(j,i) - 50));
                ySingleChannelTransmitter(k) = (200+(yClusterheads(j-1)-50) + (yTransmitterMatrix(j,i) - 50));
            end
        end
    end
    for loop1 = 1:length(xSingleChannelTransmitter)
       for loop2 = loop1+1:length(xSingleChannelTransmitter)
           if(xSingleChannelTransmitter(loop2)~=0 && ySingleChannelTransmitter(loop2)~=0 )
                distanceBetweenTransmitters = (xSingleChannelTransmitter(loop1) - xSingleChannelTransmitter(loop2))^2 + (ySingleChannelTransmitter(loop1) - ySingleChannelTransmitter(loop2))^2;
                if(distanceBetweenTransmitters < 49^2)
                    collisionSingleChannelCheck(loop1) = 1;
                    collisionSingleChannelCheck(loop2) = 1;
                    numberOfCollisionsSingleChannel = numberOfCollisionsSingleChannel + 1;
                    break;
                end
           end
       end
    end
    numberOfCollisionsSingleChannel = sum(collisionSingleChannelCheck);
    collisionSingleChannel(loopCounter) = collisionSingleChannel(loopCounter) + numberOfCollisionsSingleChannel;
end

figure();
plot(0:79,collisionSingleChannel,0:79,collisionClusters);
axis([0 80 0 30]);
title('Packet Collisions vs Time')
xlabel('Time')
ylabel('Number of Packets that Collide');
legend('Collisions on Single Channel','Collisions on Different Channels');
ylabel('Number of Packets that collide');
