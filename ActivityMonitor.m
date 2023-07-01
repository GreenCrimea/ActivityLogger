classdef ActivityMonitor

    properties
    
        data table
        abs_dat
        movmean_dat
        time_delta double
        
        labels_present = false
        sitting_intervals = []
        standing_intervals = []
        walking_intervals = []

        smooth_k = 1000
        thresholds = [0.1, 0.7]

        accuracy = 0
        range_pred_start = 0
        range_pred_end = 0

        name

    end

    methods
        
        %Constructor method
        %
        %initialised the object, reads the dataset csv into the data
        %property
        function obj = ActivityMonitor()
            
            path_to_data = input("Input the path to the accelerometer dataset: ", "s");
            obj.data = readtable(path_to_data);
            disp("Object Initiated")

        end

        %data cleaner method
        %
        %prepares the data for analysis, truncates leading and trailing
        %ends based on user input, generates initial graphs, and optionally
        %adds labels.
        function obj = data_cleaner(obj)

            %determine how many datapoints are captured per second
            [~,obj.time_delta] = min(abs(obj.data.Time_s_ - 1));
            
            j = 1;

            while j == 1
            
                %create temp copy of data for working with
                dat = obj.data;
            
                i = 1;
                n = true;

                while i == 1

                    %plot graph
                    obj.plot_data_for_trunking(dat, n);
                    n = false;
                            
                    %check if user wants to trunk / break loop
                    i = input("Would you like to truncate dataset? 1 = Yes, 0 = No :");
                
                    %if yes, trunk data
                    if i == 1
                        lead_trunk = input("Input amount to remove off the beginning of the dataset in seconds (use decimals if neccesary): ");
                        trail_trunk = input("Input amount to remove off the end of the dataset in seconds (use decimals if neccesary): ");
                        dat(1:lead_trunk * obj.time_delta,:) = [];
                        dat((end - (trail_trunk * obj.time_delta)):end,:) = [];
                        dat(:,"Time_s_") = dat(:,"Time_s_") - dat(1,"Time_s_");
            
                    end

                end

                j = input("Would you like to start again, 1 = Yes, 0 = No :");
                    
            end

            obj.data = dat;

            k = input("Would you like to add labels to the data? 1 = Yes, 0 = No :");

            labels = zeros(height(obj.data),1);

            obj.data = [obj.data, table(labels, VariableNames="Labels")];
            
            %add labels if requested
            if k == 1

                obj.labels_present = true;
                
                l = 0;

                obj.plot_data_with_labels;
                
                %prompt the user for the ranges to label
                while l == 0

                    range_start = input("Input the start of the range in seconds :");
                    range_end = input("Input the end of the range in seconds :");
                    label = input("Input what label, 1=sit, 2=stand, 3=walk :");
                    
                    if range_end*obj.time_delta > height(obj.data)
                        obj.data.Labels((range_start * obj.time_delta) +1:end) = label;
                    else
                        obj.data.Labels((range_start * obj.time_delta) +1:range_end * obj.time_delta) = label;
                    end

                    if label == 1
                        obj.sitting_intervals = [obj.sitting_intervals; range_start + (1/obj.time_delta), range_end];
                    elseif label == 2
                        obj.standing_intervals = [obj.standing_intervals; range_start + (1/obj.time_delta), range_end];
                    elseif label == 3
                        obj.walking_intervals = [obj.walking_intervals; range_start + (1/obj.time_delta), range_end];
                    end

                    obj.plot_data_with_labels;

                    l = input("are the labels complete? 1 = Yes, 0 = No :");

                    if nnz(obj.data.Labels == 0) > 1 && l == 1

                        l = 0;
                        warning("unlabelled datapoints still present, please finish labelling")

                    end

                end

            end

            disp("Data cleaning complete")

        end
        
        %Analyse data method
        %
        %analyse data by taking the absolute value, and then smoothing with
        %a moving mean filter
        function obj = analyse_data(obj)
            
            %preprocess data
            absolute = abs(obj.data{:,2:4});
            smooth_dat = movmean(absolute, obj.smooth_k);

            obj.abs_dat = absolute;
            obj.movmean_dat = smooth_dat;
            
            %add empty predicted states column to data
            if width(obj.data) < 7
                predicted_state = zeros(height(obj.data),1);
                obj.data = [obj.data, table(predicted_state, VariableNames="Predicted_state")];
            end
            
            %predict states with threshold values
            for i=1:height(obj.data)

                if smooth_dat(i) < obj.thresholds(1)
                    obj.data.Predicted_state(i) = 1;
                elseif smooth_dat(i) >= obj.thresholds(1) && smooth_dat(i) < obj.thresholds(2)
                    obj.data.Predicted_state(i) = 2;
                elseif smooth_dat(i) >= obj.thresholds(2)
                    obj.data.Predicted_state(i) = 3;
                end

            end
            
            %do accuracy calculations
            if obj.labels_present == true

                obj.accuracy = 0;

                delta = 1/height(obj.data);

                for i=1:height(obj.data)
                    
                    if obj.data.Labels(i) == obj.data.Predicted_state(i)
                        obj.accuracy = obj.accuracy + delta;

                    end

                end

                disp(strcat("Accuracy score : ", num2str(obj.accuracy * 100, "%.1f"), "%"))
                
                obj.plot_accuracy(smooth_dat);

            end

        end
        
        %predict in range method
        %
        %prompt the user for a beginning and an end of a range, then
        %calculate state in that range
        function obj = predict_in_range(obj)

            obj.range_pred_start = input("input the beginning of the range : ");
            obj.range_pred_end = input("input the end of the range : ");

            obj.plot_prediction_in_range();
            
            obj.range_pred_start = 0;
            obj.range_pred_end = 0;

        end
        
        %Plot data for trunking method
        %
        %Plot 3 graphs in a tiled layout so the data can easily be
        %truncated in the data_cleaner method
        function obj = plot_data_for_trunking(obj, dat, first)

            %plot dataset with first and last 2 seconds
            tcl = tiledlayout("flow");

            nexttile(tcl)
            p1_1 = plot(dat.Time_s_(1:obj.time_delta * 2), dat.LinearAccelerationX_m_s_2_(1:obj.time_delta * 2), "r");
            hold on
            p1_2 = plot(dat.Time_s_(1:obj.time_delta * 2), dat.LinearAccelerationY_m_s_2_(1:obj.time_delta * 2), "g");
            p1_3 = plot(dat.Time_s_(1:obj.time_delta * 2), dat.LinearAccelerationZ_m_s_2_(1:obj.time_delta * 2), "b");
            hold off
            legend(["x", "y", "z"])
            axis tight
            title("Acceleration data - First 2 seconds")
            xlabel("Time [s]")
            ylabel("Acceleration [m/s^2]")
            xticks(0:0.2:2)

            nexttile(tcl)
            p2_1 = plot(dat.Time_s_(end - (obj.time_delta * 2):end), dat.LinearAccelerationX_m_s_2_(end - (obj.time_delta * 2):end), "r");
            hold on
            p2_2 = plot(dat.Time_s_(end - (obj.time_delta * 2):end), dat.LinearAccelerationY_m_s_2_(end - (obj.time_delta * 2):end), "g");
            p2_3 = plot(dat.Time_s_(end - (obj.time_delta * 2):end), dat.LinearAccelerationZ_m_s_2_(end - (obj.time_delta * 2):end), "b");
            hold off
            legend(["x", "y", "z"])
            axis tight
            title("Acceleration data - Last 2 seconds")
            xlabel("Time [s]")
            ylabel("Acceleration [m/s^2]")
            xticks(1:0.2:100)

            nexttile(tcl, [1, 2])
            p3_1 = plot(dat.Time_s_, dat.LinearAccelerationX_m_s_2_, "r");
            hold on
            p3_2 = plot(dat.Time_s_, dat.LinearAccelerationY_m_s_2_, "g");
            p3_3 = plot(dat.Time_s_, dat.LinearAccelerationZ_m_s_2_, "b");
            hold off

            legend(["x", "y", "z"])
            axis tight
            title("Acceleration Data")
            xlabel("Time [s]")
            ylabel("Acceleration [m/s^2]")
            xticks(1:500)

            title(tcl, strcat("Trunk Dataset, run ", num2str(obj.name)))
            
            if first == true
                exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "DataForTrunkInit.png"), resolution="500")
            else
                exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "DataForTrunk.png"), resolution="500")
            end

        end

        %plot data with labels method
        %
        %Plot a graph with the current labels on it, which will update 
        %as the labels are added in the data_cleaner method
        function obj = plot_data_with_labels(obj)

            tcl = tiledlayout("flow");
            
            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_, "r", ...
                 obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_, "g", ...
                 obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_, "b")
            hold on
            
            for i = 1:height(obj.sitting_intervals)

                x = [obj.sitting_intervals(i,1), obj.sitting_intervals(i,1), obj.sitting_intervals(i,2), obj.sitting_intervals(i,2)];
                y = [12, -12, -12, 12];
                p = patch(x, y, [0.2, 0, 0]);
                p.FaceAlpha = 0.3;

            end

            for i = 1:height(obj.standing_intervals)
                
                x = [obj.standing_intervals(i,1), obj.standing_intervals(i,1), obj.standing_intervals(i,2), obj.standing_intervals(i,2)];
                y = [12, -12, -12, 12];
                p = patch(x, y, [0, 0.2, 0]);
                p.FaceAlpha = 0.3;

            end

            for i = 1:height(obj.walking_intervals)
                
                x = [obj.walking_intervals(i,1), obj.walking_intervals(i,1), obj.walking_intervals(i,2), obj.walking_intervals(i,2)];
                y = [12, -12, -12, 12];
                p = patch(x, y, [0, 0, 0.2]);
                p.FaceAlpha = 0.3;

            end

            legend(["x", "y", "z"])
            axis([0, (height(obj.data) / obj.time_delta), -12, 12])
            title(strcat("Accuracy results, run ", num2str(obj.name)))
            xlabel("Time [s]")
            ylabel("Acceleration [m/s^2]")
            xticks(1:500)

            exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "DataForLabels.png"), resolution="500")

            hold off

        end
        
        %plot abs and movmean function
        %
        %plots the data, the absolute value of the data, and the moving
        %mean smoothed data
        function obj = plot_abs_movmean(obj)
            
            tcl = tiledlayout("vertical");
            
            nexttile(tcl)
            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_, "r");
            hold on
            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_, "g");
            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_, "b");
            hold off

            legend(["x", "y", "z"])
            title("Dataset")
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            xticks(1:100)
            axis tight

            nexttile(tcl)
            plot(obj.abs_dat)

            legend(["x abs", "y abs", "z abs"])
            title("Absolute Values")
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            axis tight
            ylim([0,5])

            nexttile(tcl)
            plot(obj.movmean_dat)
            hold on
            yline(obj.thresholds(1))
            yline(obj.thresholds(2))

            ylim([0, 1])
            xlim([0, height(obj.movmean_dat)])
            legend(["x mean", "y mean", "z mean", "sit/stand", "stand/walk"])
            title(strcat("Smoothed (Moving Mean, k=", num2str(obj.smooth_k), ")"))
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            
            title(tcl, strcat("Data Analysis, run ", num2str(obj.name)))

            exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "AbsMovmean.png"), resolution="500")

        end
        
        %plot accuracy method
        %
        %plot the dataset, the smoothed moving mean, and the accuracy as
        %green and red overlays with the other 2 graphs underneath
        function obj = plot_accuracy(obj, smooth_dat)

            tcl = tiledlayout("flow");

            nexttile(tcl)
            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_, "r");
            hold on
            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_, "g");
            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_, "b");
            hold off

            title("Dataset")
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            xticks(1:100)
            axis tight

            nexttile(tcl)
            plot(smooth_dat)
            hold on
            yline(obj.thresholds(1))
            yline(obj.thresholds(2))

            ylim([0, 1])
            xlim([0, height(smooth_dat)])
            title(strcat("Smoothed (Moving Mean, k=", num2str(obj.smooth_k), ")"))
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            
            nexttile(tcl, [1, 2])

            g_intervals = [];
            b_intervals = [];

            prev = 0;

            for i=1:height(obj.data)
                if obj.data.Labels(i) == obj.data.Predicted_state(i)
                    if i == 1
                        g_intervals = [g_intervals; 1, 0];
                        prev = 0;
                    elseif i == height(obj.data)
                        g_intervals(end,2) = i;
                    else
                        if prev == 1
                            prev = 0;
                            g_intervals = [g_intervals; i, 0];
                        else
                            g_intervals(end,2) = i;
                        end
                    end

                else
                    if i == 1
                        b_intervals = [b_intervals; 1, 0];
                        prev = 0;
                    elseif i == height(obj.data)
                        b_intervals(end,2) = i;
                    else
                        if prev == 0
                            prev = 1;
                            b_intervals = [b_intervals; i, 0];
                        else
                            b_intervals(end,2) = i;
                        end
                    end

                end

            end

            yline(0)
            hold on

            g_intervals = g_intervals / obj.time_delta;
            b_intervals = b_intervals / obj.time_delta;

            for i=1:height(g_intervals)
                x = [g_intervals(i,1), g_intervals(i,1), g_intervals(i,2), g_intervals(i,2)];
                y = [10, -10, -10, 10];
                p = patch(x, y, [0, 0.5, 0]);
                p.FaceAlpha = 0.3;
                p.EdgeColor = "None";
            end

            for i=1:height(b_intervals)
                x = [b_intervals(i,1), b_intervals(i,1), b_intervals(i,2), b_intervals(i,2)];
                y = [10, -10, -10, 10];
                p = patch(x, y, [0.5, 0, 0]);
                p.FaceAlpha = 0.3;
                p.EdgeColor = "None";
            end

            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_);
            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_);
            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_);

            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationX_m_s_2_),obj.smooth_k)*10);
            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationY_m_s_2_),obj.smooth_k)*10);
            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationZ_m_s_2_),obj.smooth_k)*10);

            yline(obj.thresholds(1) * 10)
            yline(obj.thresholds(2) * 10)

            title(strcat("Accuracy = ", num2str(obj.accuracy * 100,"%.1f"), "%"))
            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]")
            xticks(1:100)
            xlim([0, height(obj.data) / obj.time_delta])
            ylim([-10, 10])
        
            hold off

            title(tcl, strcat("Accuracy results, run ", num2str(obj.name)))

            exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "Accuracy.png"), resolution="500")

        end
        
        %Plot prediction in range method
        %
        %prompt the user for 2 points and display the prediction for the
        %state between those points. calculate accuracy score for that
        %prediction.
        function obj = plot_prediction_in_range(obj)

            tcl = tiledlayout(8,2, 'TileSpacing','Compact','Padding','Compact');

            r = (obj.range_pred_end - obj.range_pred_start) * obj.time_delta;
            acc = 0;

            for i=1:r

                if obj.data.Labels((obj.range_pred_start*obj.time_delta) + i) == obj.data.Predicted_state((obj.range_pred_start*obj.time_delta) + i)
                    acc = acc + 1/r;
                end

            end

            acc = acc * 100;

            num_1 = nnz(obj.data.Predicted_state(obj.range_pred_start * obj.time_delta:obj.range_pred_end * obj.time_delta) == 1)/r;
            num_2 = nnz(obj.data.Predicted_state(obj.range_pred_start * obj.time_delta:obj.range_pred_end * obj.time_delta) == 2)/r;
            num_3 = nnz(obj.data.Predicted_state(obj.range_pred_start * obj.time_delta:obj.range_pred_end * obj.time_delta) == 3)/r;


            nexttile(tcl, [2,1])
            %zoomed on range plot
            %plot zoom x

            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_, "r");
            hold on

            plot(obj.data.Time_s_, obj.movmean_dat(:,1) * 15, "r")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,1)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,1) * 15);

            if y1 > 15
                scatter(obj.range_pred_start, 14.5, "ok", LineWidth=1.5)
                y1 = 14.5;
            else
                scatter(obj.range_pred_start, y1, "ok", LineWidth=1.5)
            end

            if y2 > 15
                scatter(obj.range_pred_end, 14.5, "ok", LineWidth=1.5)
                y2 = 14.5;
            else
                scatter(obj.range_pred_end, y2, "ok", LineWidth=1.5)
            end
            
            plot([obj.range_pred_start, obj.range_pred_end], [y1, y2], "-.k", LineWidth=1.5)
            xx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            xy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 1);

            plot(xx, xy * 15, Color=[0.6,0.5,0.5], LineWidth=1.5)

            ylim([-15, 15])
            xlim([obj.range_pred_start - 2, obj.range_pred_end + 2])

            %plot zoom y

            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_, "g");
            hold on

            plot(obj.data.Time_s_, obj.movmean_dat(:,2) * 15, "g")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,2)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,2) * 15);

            yx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            yy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 2);

            plot(yx, yy * 15, Color=[0.5,0.6,0.5], LineWidth=1.5)

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)

            %plot zoom z

            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_, "b");
            hold on

            plot(obj.data.Time_s_, obj.movmean_dat(:,3) * 15, "b")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,3)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,3) * 15);

            zx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            zy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 3);

            plot(zx, zy * 15, Color=[0.5,0.5,0.6], LineWidth=1.5)

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)
            title("Zoomed on range")
            hold off

            nexttile(tcl, [2,1])
            %accuracy plot

            y1 = obj.movmean_dat(obj.range_pred_start * obj.time_delta,1)* 10;
            y2 = obj.movmean_dat(obj.range_pred_end * obj.time_delta,1) * 10;

            s = obj.range_pred_start;         
            e = obj.range_pred_end;
            
            hold on
            xx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            xy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 1);

            plot(xx, xy * 10, Color=[0.6,0.5,0.5], LineWidth=1.5)

            yx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            yy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 2);

            plot(yx, yy * 10, Color=[0.5,0.6,0.5], LineWidth=1.5)

            zx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            zy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 3);

            plot(zx, zy * 10, Color=[0.5,0.5,0.6], LineWidth=1.5)

            plot([obj.range_pred_start, obj.range_pred_end], [y1, y2], "-.k", LineWidth=1.5)

            g_intervals = [];
            b_intervals = [];

            prev = 0;

            for i=1:height(obj.data)
                if obj.data.Labels(i) == obj.data.Predicted_state(i)
                    if i == 1
                        g_intervals = [g_intervals; 1, 0];
                        prev = 0;
                    elseif i == height(obj.data)
                        g_intervals(end,2) = i;
                    else
                        if prev == 1
                            prev = 0;
                            g_intervals = [g_intervals; i, 0];
                        else
                            g_intervals(end,2) = i;
                        end
                    end

                else
                    if i == 1
                        b_intervals = [b_intervals; 1, 0];
                        prev = 0;
                    elseif i == height(obj.data)
                        b_intervals(end,2) = i;
                    else
                        if prev == 0
                            prev = 1;
                            b_intervals = [b_intervals; i, 0];
                        else
                            b_intervals(end,2) = i;
                        end
                    end

                end

            end

            hold on

            g_intervals = g_intervals / obj.time_delta;
            b_intervals = b_intervals / obj.time_delta;

            for i=1:height(g_intervals)
                x = [g_intervals(i,1), g_intervals(i,1), g_intervals(i,2), g_intervals(i,2)];
                y = [10, -10, -10, 10];
                p = patch(x, y, [0, 0.5, 0]);
                p.FaceAlpha = 0.3;
                p.EdgeColor = "None";
            end

            for i=1:height(b_intervals)
                x = [b_intervals(i,1), b_intervals(i,1), b_intervals(i,2), b_intervals(i,2)];
                y = [10, -10, -10, 10];
                p = patch(x, y, [0.5, 0, 0]);
                p.FaceAlpha = 0.3;
                p.EdgeColor = "None";
            end

            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_);
            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_);
            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_);

            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationX_m_s_2_),obj.smooth_k)*10);
            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationY_m_s_2_),obj.smooth_k)*10);
            plot(obj.data.Time_s_, movmean(abs(obj.data.LinearAccelerationZ_m_s_2_),obj.smooth_k)*10);

            xlim([obj.range_pred_start - 2, obj.range_pred_end + 2])
            ylim([-10, 10])

            if y1 > 10
                scatter(s, 9.5, "ok", LineWidth=1.5)
                hold on
                y1 = 9.5;
            else
                scatter(s, y1, "ok", LineWidth=1.5)
            end

            if y2 > 10
                scatter(e, 9.5, "ok", LineWidth=1.5)
                y2 = 9.5;
            else
                scatter(e, y2, "ok", LineWidth=1.5)
            end

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)

            title("Accuracy overlay")


            nexttile(tcl, [2,2])
            %plot x

            plot(obj.data.Time_s_, obj.data.LinearAccelerationX_m_s_2_, "r");
            hold on

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)

            title("X axis")

            plot(obj.data.Time_s_, obj.movmean_dat(:,1) * 15, "r")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,1)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,1) * 15);

            if y1 > 15
                scatter(obj.range_pred_start, 14.5, "ok", LineWidth=1.5)
                y1 = 14.5;
            else
                scatter(obj.range_pred_start, y1, "ok", LineWidth=1.5)
            end

            if y2 > 15
                scatter(obj.range_pred_end, 14.5, "ok", LineWidth=1.5)
                y2 = 14.5;
            else
                scatter(obj.range_pred_end, y2, "ok", LineWidth=1.5)
            end
            
            plot([obj.range_pred_start, obj.range_pred_end], [y1, y2], "-.k", LineWidth=1.5)
            xx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            xy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 1);

            plot(xx, xy * 15, Color=[0.6,0.5,0.5], LineWidth=1.5)

            ylim([-15, 15])
            xlim([0, height(obj.data) / obj.time_delta])

            nexttile(tcl, [2,2])
            %plot y

            plot(obj.data.Time_s_, obj.data.LinearAccelerationY_m_s_2_, "g");
            hold on

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)

            title("Y axis")

            plot(obj.data.Time_s_, obj.movmean_dat(:,2) * 15, "g")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,2)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,2) * 15);

            if y1 > 15
                scatter(obj.range_pred_start, 14.5, "ok", LineWidth=1.5)
                y1 = 14.5;
            else
                scatter(obj.range_pred_start, y1, "ok", LineWidth=1.5)
            end

            if y2 > 15
                scatter(obj.range_pred_end, 14.5, "ok", LineWidth=1.5)
                y2 = 14.5;
            else
                scatter(obj.range_pred_end, y2, "ok", LineWidth=1.5)
            end
            
            plot([obj.range_pred_start, obj.range_pred_end], [y1, y2], "-.k", LineWidth=1.5)
            yx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            yy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 2);

            plot(yx, yy * 15, Color=[0.5,0.6,0.5], LineWidth=1.5)

            ylim([-15, 15])
            xlim([0, height(obj.data) / obj.time_delta])

            nexttile(tcl, [2,2])
            %plot z

            plot(obj.data.Time_s_, obj.data.LinearAccelerationZ_m_s_2_, "b");
            hold on

            xlabel("Time [s]")
            ylabel("Acc. [m/s^2]", FontSize=6)
            title("Z axis")

            plot(obj.data.Time_s_, obj.movmean_dat(:,3) * 15, "b")
            y1 = mean(obj.movmean_dat(obj.range_pred_start * obj.time_delta,3)* 15);
            y2 = mean(obj.movmean_dat(obj.range_pred_end * obj.time_delta,3) * 15);

            if y1 > 15
                scatter(obj.range_pred_start, 14.5, "ok", LineWidth=1.5)
                y1 = 14.5;
            else
                scatter(obj.range_pred_start, y1, "ok", LineWidth=1.5)
            end

            if y2 > 15
                scatter(obj.range_pred_end, 14.5, "ok", LineWidth=1.5)
                y2 = 14.5;
            else
                scatter(obj.range_pred_end, y2, "ok", LineWidth=1.5)
            end

            plot([obj.range_pred_start, obj.range_pred_end], [y1, y2], "-.k", LineWidth=1.5)
            zx = obj.range_pred_start:1/obj.time_delta:obj.range_pred_end;
            zy = obj.movmean_dat(obj.range_pred_start*obj.time_delta:obj.range_pred_end*obj.time_delta, 3);

            plot(zx, zy * 15, Color=[0.5,0.5,0.6], LineWidth=1.5)

            ylim([-15, 15])
            xlim([0, height(obj.data) / obj.time_delta])

            nums = [num_1, num_2, num_3];
            [~,idx] = max(nums);
            str = ["sitting", "standing", "walking"];

            title(tcl, strcat("From ", num2str(obj.range_pred_start), "s to ", num2str(obj.range_pred_end), "s, the user was ", str(idx), " (", num2str(acc, "%.0f"), "% Accurate)"))
            
            exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "RangeSelection.png"), resolution="500")

        end
        
        %Plot results method
        %
        %Plot the results of all the experiments and show all the data
        %gathered
        function obj = plot_results(obj, results)
            
            %stem chart
            tcl = tiledlayout(2,3);
            nexttile(tcl, [2,2])

            m = mean(results);

            stem(results, ":diamondr", LineWidth=1)
            xlim([0,length(results) + 1])
            ylim([0,100])
            xticks(1:length(results) + 1)
            yticks(0:10:100)

            grid on

            xlabel("Run Number")
            ylabel("Accuracy Percentage %")

            yline(m, "-.k", LineWidth=2)

            legend(["Results", "Average Result"])

            title("Individual runs")
            
            %boxchart
            nexttile(tcl,[2,1])

            boxchart(results, BoxFaceColor=[0.3, 0.3, 0.3])
            ylim([0,100])
            yticks(0:10:100)

            grid on

            ylabel("Accuracy Percentage %")

            title("Overall Results")

            title(tcl, strcat("Results from ", num2str(length(results)), " runs, ", num2str(m, "%.1f"), " average Accuracy."))

            exportgraphics(tcl, strcat("graphics/", num2str(obj.name), "Results.png"), resolution="500")

        end
    end

end
  

