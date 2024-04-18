classdef DiffRecon_ToolBox

    methods(Static)
        
        %% General function to calculate the Tensor out of signal attenuation
        function  Gif_KM(Dcm, enum, FileName)
            % Generate an animated Gif for each slice of Dcm
            %
            %
            % SYNTAX:   Gif_KM(Dcm, enum, 'Average')
            %
            % INPUTS:   listing - list of files (ex: listing = dir(dcm_dir))
            %
            %           enum - existing enumerator
            %
            %           dataset - specify the number of the given serie
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            disp('Gif')
            h = waitbar(0,['Gif' FileName '...']);
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    j=1;
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                tmpDataDcm=squeeze(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set));
                                if j==1
                                    imwrite( double( imresize(tmpDataDcm,[4*size(tmpDataDcm,1) 4*size(tmpDataDcm,2)],'nearest') ),fullfile(enum.recon_dir, 'Gif',[ FileName '_' num2str(cpt_set) '_' num2str(cpt_slc) '.gif']),'gif', 'Loopcount',inf,'DelayTime',0.1);   %%%% First image, delay time = 0.1s
                                    j=2;
                                else
                                    imwrite( double( imresize(tmpDataDcm,[4*size(tmpDataDcm,1) 4*size(tmpDataDcm,2)],'nearest') ),fullfile(enum.recon_dir, 'Gif',[ FileName '_' num2str(cpt_set) '_' num2str(cpt_slc) '.gif']),'gif','WriteMode','append','DelayTime',0.1); %%%% Following images

                                end
                            end
                        end
                    end
                    waitbar(cpt_slc/size(enum.datasize(cpt_set).slc,2),h);
                end
            end
            close(h);
        end
        function   [Dcm2, enum2]= Demosa_KM(Dcm, enum)
            % Decompose the mosa diffusion matrices on slice diffusion matrices based
            % on the informations find in the dicom headers and stored in 'enum'.
            % Update enum to count the number of slices properly
            %
            %
            % SYNTAX:  [Dcm2 enum2]= Demosa_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum2 - Structure which contains information about the dataset
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com


            Dcm2=[];
            enum2=enum;
            div=ceil(sqrt(double(enum.mosa)));
            if enum.mosa>1
                disp('Unmosaic');
                h = waitbar(0,'Unmosaic...');
                for cpt_set=1:1:enum.nset
                    for cpt_slc=1:1:enum.datasize(cpt_set).slc
                        for cpt_b=1:1:enum.datasize(cpt_set).b
                            for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                                for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg


                                    tmpDataDcm=[];
                                    tmpDataDcm2=[];
                                    tmpDataDcm=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);

                                    x = size(tmpDataDcm,1)/div;                     %The information of slices dimensions is also store here :tmpInfoDcm.AcquisitionMatrix(2);
                                    y = size(tmpDataDcm,2)/div;                     % and here :tmpInfoDcm.AcquisitionMatrix(3); But recently I had problem with this field so I prefer recalcul
                                    j=1;
                                    for cpt3=1:1:div
                                        for cpt4=1:1:div
                                            if j<=(enum.mosa)
                                                tmpDataDcm2(:,:,j)=tmpDataDcm(((cpt3-1)*x)+1:(cpt3*x),((cpt4-1)*y)+1:(cpt4*y));
                                                if isempty(find(enum2.slc== (enum2.slc(1)+(j-1)*10)))
                                                    enum2.slc=[enum2.slc (enum2.slc(1)+(j-1)*10)];
                                                end
                                                j=j+1;
                                            end
                                        end
                                    end

                                    Dcm2(:,:,:,cpt_b,cpt_dir,cpt_avg,cpt_set)=tmpDataDcm2;

                                end
                            end
                        end
                        waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                    end
                end
                close(h);

                for cpt_set=1:1:enum.nset
                    enum2.datasize(cpt_set).slc=enum.datasize(cpt_set).slc*enum.mosa;
                    for cpt=1:1:enum.mosa
                        enum2.dataset(cpt_set).slc(cpt)=enum2.dataset(cpt_set).slc(1);
                    end
                end
            else
                Dcm2=Dcm;
            end
        end
        function [Dcm2]= RigidRegistration_before_KM(Dcm, enum)
            % Register the DWI and nDWI matrices per SLICE based on a rigid method.
            % Registration reference is automatically chosen to be the image with the
            % maximum signal intensity (usually the nDWI b=0 s/mm² images)
            %
            % SYNTAX:  [Dcm2]= RigidRegistration_before_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            [optimizer, metric] = imregconfig('multimodal');
            disp('Rigid registration before')
            h = waitbar(0,'Rigid registration before...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            ref=zeros(size(Dcm,1),size(Dcm,2));
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                if (mean(mean(ref))<mean(mean(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set))))
                                    ref=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                                end
                            end
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                tmpIn=squeeze(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set));
                                if (~isnan(max(tmpIn(:))))
                                    Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set)=  imregister(tmpIn, ref, 'affine' , optimizer, metric);
                                else
                                     Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set)=tmpIn;
                                end
                            end
                        end
                    end

                    waitbar(cpt_slc/size(enum.slc,2),h);
                end
            end

            close(h);

        end
        function [Dcm2]= NonRigidRegistration_KM(Dcm, enum)
            % Register the DWI and nDWI matrices per SLICE based on a nonrigid method.
            % Registration reference is automatically chosen to be the image with the
            % maximum signal intensity (usually the nDWI b=0 s/mm² images). Reject
            % images that are not properlly register and generate blank images instead
            %
            % SYNTAX:  [Dcm2]= NonRigidRegistration_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            disp('NonRigid registration')
            h = waitbar(0,'NonRigid registration...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    ref=zeros(size(Dcm,1),size(Dcm,2));
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                if (mean(mean(ref))<mean(mean(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set))))
                                    ref=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                                end
                            end
                        end
                    end
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                tmpIn=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                                if (~isnan(max(tmpIn(:))))
                                    [Mp,eng] = DiffRegistrationLinear(ref,tmpIn);%%DiffRegistrationLinear
                                    if eng<550
                                        Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg)=Mp;
                                    else
                                        Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg)=zeros(size(Mp,1),size(Mp,2));
                                        % cpt_avg_tmp=cpt_avg_tmp-11;
                                    end
                                else
                                     Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg)=tmpIn;
                                end
                            end
                        end
                    end
                    waitbar(cpt_slc/size(enum.slc,2),h);
                end
            end

            close(h);

        end
        function [Dcm2]= VPCA_KM(Dcm, enum,pca_min_ernegy)
            % Aply a 24x24 PCA Filter on the DWI and nDWI matrices through
            % the average dimension.
            %
            % SYNTAX:  [Dcm2]= VPCA_KM(Dcm, enum,pca_min_ernegy);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            %           pca_min_ernegy - Rejection limit for the PCA filter
            %                                   (usually 80%)
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            disp('PCA')
            h = waitbar(0,'PCA filter...');

            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            tmpDataDcm=[];
                            for cpt_avg=1:1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                tmpDataDcm(:,:,cpt_avg)=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                            end

                            for k=24:-1:1
                                if mod(size(tmpDataDcm,1),k)==0
                                    break
                                end
                            end
                            divx=k;
                            for k=24:-1:1
                                if mod(size(tmpDataDcm,2),k)==0
                                    break
                                end
                            end
                            divy=k;
                            stepx=size(tmpDataDcm,1)/divx;
                            stepy=size(tmpDataDcm,2)/divy;
                            tmpDataDcm2=zeros(size(tmpDataDcm));
                            for cptx=1:1:divx
                                for cpty=1:1:divy
                                    tmpDataDcm2(((cptx-1)*stepx)+1:(cptx*stepx),((cpty-1)*stepy)+1:(cpty*stepy),:)=DiffRecon_ToolBox.Pca_local_KM(tmpDataDcm(((cptx-1)*stepx)+1:(cptx*stepx),((cpty-1)*stepy)+1:(cpty*stepy),:),pca_min_ernegy); % Execute Pca
                                end
                            end



                            for cpt_avg=1:1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                Dcm2(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg)=tmpDataDcm2(:,:,cpt_avg,cpt_set);
                            end
                        end
                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end
            end
            close(h);

        end

        function [matOut] = Pca_local_KM(matIn,pca_min_ernegy)

            %%%%%%%%%%%%%%%%%%%%% Sub the [n,p,dim] matrix %%%%%%%%%%%%%%%%%%%%%%

            %matIn=tmpDataDcm;
            dim=size(matIn,3);

            matIn=double(matIn);

            [n,p]=size(matIn(:,:,1));

            Image=[];
            Vector=[];
            X=[];
            for i=1:1:dim
                Image(i).dat = matIn(:,:,i);
                Vector(i).dat= Image(i).dat(:);
            end


            for i=1:1:dim
                Vector(i).mean=mean(Vector(i).dat);
                Vector(i).dat=Vector(i).dat-Vector(i).mean;
                X=[X Vector(i).dat];
            end


            %on crée la matrice ayant 3 individus et n*p réalisations
            %X=[vKL_R,vKL_G,vKL_B];

            % on calcule la matrice d'inertie, matrice de covariance
            %V=(1/(n*p)).*(X'*X);
            v=cov(X);
            %on calcule les valeurs propres et les vecteurs propres
            %[V,D] = EIG(X) produces a diagonal matrix D of eigenvalues and a
            % full matrix V whose columns are the corresponding eigenvectors so
            % that X*V = V*D.
            [mat_vect_p,D]=eig(v);

            % D est une matrice avec les valeurs propres sur la diagonale,
            % on souhaite les avoir dans un vecteur
            vpKL=eig(D);

            % 'contribution des différents axes'
            %
            % Energy_KL1=[num2str((vpKL(1))/(vpKL(1)+vpKL(2)+vpKL(3))*100),' %']
            % Energy_KL2=[num2str((vpKL(2))/(vpKL(1)+vpKL(2)+vpKL(3))*100),' %']
            % Energy_KL3=[num2str((vpKL(3))/(vpKL(1)+vpKL(2)+vpKL(3))*100),' %']
            %
            % Quality=[num2str(((vpKL(2)+vpKL(3)))/(vpKL(1)+vpKL(2)+vpKL(3))*100),' %']
            maxEnergy=0;
            for i=1:1:dim
                maxEnergy=maxEnergy+vpKL(i);
                Index(i)=false;
            end

            e=0;
            i=0;
            for i=1:1:dim
                Y =find(vpKL== max(vpKL));
                if e <= pca_min_ernegy
                    Index(Y)=true; % Note the index of the value
                    i=i+1;
                    e=e+100*vpKL(Y)/maxEnergy;
                    vpKL(Y)=[];
                end
            end
            %Quality=[num2str(e)];
            %C projection de l'image sur la nouvelle base
            C=X*mat_vect_p;
            canal=[];
            for i=1:1:dim
                if Index(i)
                    canal(i).dat=C(:,i);
                else
                    canal(i).dat=zeros(n*p,1);
                end
            end

            %===============================================%
            % RECONSTITUTION AVEC UN MAX DE VALEURS PROPRES %
            %===============================================%
            C_rec=[];
            for i=1:1:dim
                C_rec=[C_rec canal(i).dat]; %zeros(n*p,1) if don't keep vector
            end


            X_rec=C_rec*mat_vect_p';

            C_rec=[];

            for i=1:1:dim
                %     if i==1
                %         C_rec=[C_rec zeros(n*p,1)];
                %     else
                %         C_rec=[C_rec X_rec(:,i)]; %zeros(n*p,1) if don't keep vector
                %     end
                C_rec=[C_rec X_rec(:,i)]; %zeros(n*p,1) if don't keep vector
            end



            tmp=[];
            for i=1:1:dim
                tmp2=C_rec(:,i);
                tmp(:,:)=reshape(tmp2(:),n,p);
                tmp(:,:)=tmp(:,:)+Vector(i).mean;
                matOut(:,:,i)=tmp(:,:);
            end


            matOut=uint16(matOut);

        end

        function [Dcm2 enum2]= tMIP_KM(Dcm, enum)
            % Aply Maximal Intensity Projection on the DWI and nDWI matrices through
            % the average dimension.
            %
            % Update the number of averages in enum
            %
            % SYNTAX:  [Dcm2 enum2]= tMIP_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %
            %           enum2 - Structure which contains information about the dataset
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com


            enum2=enum;
            Dcm2=[];
            DcmB02=[];
            disp('tMIP data')
            h = waitbar(0,'tMIP data...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,1,cpt_set)=nanmax(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,:,cpt_set),[],6);
                            end
                            enum2.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg=1;
                        end
                    end
                end
                waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
            end
            close(h);

        end
        function [Dcm2 enum2]= Average_KM(Dcm, enum)
            % Perform averaging on the DWI and nDWI matrices
            %
            % Update the number of averages in enum
            %
            %
            % SYNTAX:  [Dcm2 enum2]= Average_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum2 - Structure which contains information about the dataset
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            enum2=enum;
            Dcm2=[];
            disp('Average data')
            h = waitbar(0,'Average data...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            tmpDcm=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg,cpt_set);
                            tmpDcm(tmpDcm==0)=nan;
                            Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,1,cpt_set)=nanmean(tmpDcm,6);
                            enum2.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg=1;
                        end
                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end
            end
            Dcm2(isnan(Dcm2))=0;
            close(h);

        end

        function [Dcm2 enum2]= Average_and_Reject_KM(Dcm, enum,ADC_limit)
            % Perform averaging on the DWI and nDWI matrices
            %
            % Update the number of averages in enum
            %
            %
            % SYNTAX:  [Dcm2 enum2]= Average_and_Reject_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum2 - Structure which contains information about the dataset
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            enum2=enum;
            Dcm2=[];
            disp('Average Reject data')
            h = waitbar(0,'Average Reject data...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            Mask_Avg=[];
                            if cpt_b>1

                                tmpADC=log(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg,cpt_set )./repmat(Dcm(:,:,cpt_slc,1,1,1,cpt_set),1,1,1,1,1,enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg))/-enum.b(cpt_b); % tmpADC= log(S/S0)/-b-value
                                tmpADC(tmpADC>ADC_limit|tmpADC<0.000001)=0;
                                tmpADC(tmpADC>0.000001)=1;

                                Mask_Avg=sum(tmpADC,6);

                                Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,1,cpt_set)=sum(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,1:enum.dataset(1).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg,cpt_set).*tmpADC,6)./Mask_Avg;
                            else
                                Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,1,cpt_set)=mean(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,1:enum.dataset(1).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg,cpt_set),6);
                            end
                            enum2.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg=1;

                        end
                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end
            end

            Dcm2(isnan(Dcm2))=0;
            Dcm2(isinf(Dcm2))=0;
            close(h);

        end
        function [Dcm2]= RigidRegistration_KM(Dcm, enum)
            % Register the DWI and nDWI matrices per SLICE based on a rigid method.
            % Registration reference is automatically chosen to be the image with the
            % maximum signal intensity (usually the nDWI b=0 s/mm² images)
            %
            % SYNTAX:  [Dcm2]= RigidRegistration_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            [optimizer, metric] = imregconfig('multimodal');
            disp('Rigid registration')
            h = waitbar(0,'Rigid registration...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    ref=zeros(size(Dcm,1),size(Dcm,2));
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                if (mean(mean(ref))<mean(mean(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set))))
                                    ref=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                                end
                            end
                        end
                    end
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                tmpIn=Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set);
                                if (~isnan(max(tmpIn(:))))
                                    Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set)=  imregister(tmpIn, ref, 'affine', optimizer, metric);
                                else
                                    Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set)=tmpIn;
                                end
                            end
                        end
                    end
                    waitbar(cpt_slc/size(enum.slc,2),h);
                end
            end

            close(h);

        end
        function [Dcm2, enum]=Scaling_KM(Dcm,enum,opt)
            % Register the DWI and nDWI matrices per SLICE based on a rigid method.
            % Registration reference is automatically chosen to be the image with the
            % maximum signal intensity (usually the nDWI b=0 s/mm² images)
            %
            % SYNTAX:  [Dcm2]= RigidRegistration_KM(Dcm, enum);
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %           enum - Structure which contains information about the dataset
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages]
            %
            %           enum - Structure which contains information about the dataset
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com
            enum2=enum;
            fovratio=round(opt(1)/enum.Pixel(1));
            ratio=enum.Pixel(1)/opt(2);
            Dcm_square=Dcm(end/2-round(fovratio/2)+1:end/2+round(fovratio/2)-1,end/2-round(fovratio/2)+1:end/2+round(fovratio/2)-1,:,:,:,:,:,:);
            Dcm2=imresize(Dcm_square,opt(1)/2/fovratio);
            enum2.Pixel=[opt(2) opt(2)];
        end

        function [Dcm2 enum2]= Interpolation_KM(Dcm, enum)
        % Interpolate the DWI and nDWI matrices by zeros filling
        %
        %
        % SYNTAX:  [Dcm2 DcmB02]= Demosa_KM(Dcm, DcmB0, enum);
        %  
        %
        % INPUTS:   Dcm - DWI image matrix
        %                 [y x slices b-values directions averages dataset]
        %           
        %           enum - Structure which contains information about the dataset 
        %          
        % OUTPUTS:  Dcm2 - Interpolated DWI image matrix 
        %                 [y*2 x*2 slices b-values directions averages dataset]
        %
        %           enum2 - Structure which contains information about the dataset 
        %           
        %
        % Kevin Moulin 04.17.2024
        % Kevin.Moulin@cardio.chboston.org
        % Kevin.Moulin.26@gmail.com
           
            Dcm2=[];
            disp('Zero filling data') 
            h = waitbar(0,'Zero filling data...');
            enum2=enum;
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                 for cpt_b=1:1:enum.datasize(cpt_set).b     
                   for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir  
                           for cpt_avg=1:1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                 tmpZero=[];
                                 tmpKspace=[];
                                 tmpZero=zeros(2*size(Dcm(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg),1),2*size(Dcm(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg,cpt_set),2));
                                 tmpKspace=fftshift(fft2(squeeze(Dcm(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg,cpt_set))));
                                 tmpZero((size(tmpKspace,1)/2):(size(tmpKspace,1)+size(tmpKspace,1)/2-1),(size(tmpKspace,2)/2):(size(tmpKspace,2)+size(tmpKspace,2)/2-1))=tmpKspace;
                                 Dcm2(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg,cpt_set)=abs(ifft2(fftshift(tmpZero)))*4;             
                           end           
                       end
                   end
                   waitbar(cpt_slc/size(enum.slc,2),h);
                end
            end
            enum2.Pixel=enum.Pixel/2;
            close(h);    
        
        end
        function [Dcm2 enum2]= Trace_KM(varargin)
            %  Generate Trace Matrices from the DWI and nDWI matrices by averaging
            %  every diffusion directions (practical but incorrect solution)
            %
            %  Update the number of directions in enum
            %
            % SYNTAX:  [Dcm2 enum2]= Trace_KM(Dcm, enum,Trace_mod)
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            %           Trace_mod - (1) mean (2) median (3) min (4) max
            %
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum2 - Structure which contains information about the dataset
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            narginchk(2,3);
            if numel(varargin) == 2
                Dcm=varargin{1};
                enum=varargin{2}(1);
                mod=1;

            else
                Dcm=varargin{1};
                enum=varargin{2}(1);
                mod=varargin{3}(1);
            end


            enum2=enum;
            Dcm2=[];
            disp('Trace')
            h = waitbar(0,'Trace...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(1).nb_avg

                            %Dcm2(:,:,cpt_slc,(cpt_b-1),1,:)=nthroot(tmpDcmB2,enum.dataset(cpt_b).dirNum);
                            if(mod==1)
                                Dcm2(:,:,cpt_slc,cpt_b,1,cpt_avg,cpt_set )=mean(Dcm(:,:,cpt_slc,cpt_b,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir,cpt_avg,cpt_set),5); % For now just mean but later calculate true trace !
                            elseif(mod==2)
                                Dcm2(:,:,cpt_slc,cpt_b,1,cpt_avg,cpt_set )=median(Dcm(:,:,cpt_slc,cpt_b,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir,cpt_avg,cpt_set),5); % For now just mean but later calculate true trace !
                            elseif (mod==3)
                                Dcm2(:,:,cpt_slc,cpt_b,1,cpt_avg,cpt_set )=max(Dcm(:,:,cpt_slc,cpt_b,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir,cpt_avg,cpt_set),[],5); % For now just mean but later calculate true trace !
                            elseif (mod==4)
                                Dcm2(:,:,cpt_slc,cpt_b,1,cpt_avg,cpt_set )=min(Dcm(:,:,cpt_slc,cpt_b,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir,cpt_avg,cpt_set),[],5); % For now just mean but later calculate true trace !
                            else
                                Dcm2(:,:,cpt_slc,cpt_b,1,cpt_avg,cpt_set )=mean(Dcm(:,:,cpt_slc,cpt_b,1:enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir,cpt_avg,cpt_set),5); % For now just mean but later calculate true trace !
                            end
                            enum2.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir =1;
                        end
                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end
            end
            close(h);

        end
        function [Dcm2]= Norm_KM(Dcm, enum)
            %  Normalize DWI matrices by dividing it by the nDWI matrices
            %
            %
            % SYNTAX:  [Dcm2]= Norm_KM(Dcm, enum)
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            %
            % OUTPUTS:  Dcm2 - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            disp('Norm data (S/S0)')
            h = waitbar(0,'Norm (S/S0)...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=1:1:enum.datasize(cpt_set).b
                        for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir
                            for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg
                                Dcm2(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set)=squeeze(Dcm(:,:,cpt_slc,cpt_b,cpt_dir,cpt_avg,cpt_set))./squeeze(Dcm(:,:,cpt_slc,1,1,1,cpt_set));
                            end
                        end
                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end
            end
            close(h);
            Dcm2(isnan(Dcm2))=0;
            Dcm2(isinf(Dcm2))=0;
        end
        function [Dcm2]= Mask_KM(Dcm,min, max)

            % Generate a mask matrix
            %
            % SYNTAX:  [Dcm2]= Mask_KM(Dcm,min, max)
            %
            %
            % INPUTS:   Dcm - Image matrix
            %                 [y x slices ..]
            %
            %           min - Seuil minimal for the mask generation
            %
            %           max - Seuil maximal for the mask generation
            %
            %
            % OUTPUTS:  Dcm2 - image matrix
            %                 [y x slices ..]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Dcm2=[];
            disp('Mask creation')
            Dcm2=Dcm;

            Dcm2(Dcm2>max)=0;
            Dcm2(Dcm2<min)=0;

        end
        function[P_Endo,P_Epi,LV_Mask,Mask_Depth]= ROI_KM(Dcm)
            %  Draw an Endo and Epi ROI for each Slice and apply it to the DWI matrix
            %
            % SYNTAX:  [P_Endo,P_Epi,LV_mask_slc]= ROI_KM(Dcm)
            %
            %
            % INPUTS:   Dcm - Image matrix
            %                 [y x slices]
            %
            %
            % OUTPUTS:  P_Endo - List of Coordinates of the Endocardium ROI
            %
            %           P_Epi - List of Coordinates of the Epicardium ROI
            %
            %           LV_Mask - Mask matrix
            %                 [y x slices]
            %
            %           Mask_Depth - Mask of depth based on the Epi/Endo countour
            %                 [y x slices]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            P_Endo=[];
            P_Epi=[];
            [Xq,Yq] = meshgrid(1:size(Dcm,2),1:size(Dcm,1));
            disp('Create ROI')
            for cpt_slc=1:1:size(Dcm,3)
                [epicardium, endocardium, LV_tmp] = DiffRecon_ToolBox.Spline_Segmentation(Dcm(:,:,cpt_slc,1,1,1,1), 30, 30);
                LV_Mask(:,:,cpt_slc)=LV_tmp;
                P_Endo(:,:,cpt_slc)=endocardium;
                P_Epi(:,:,cpt_slc)=epicardium;


                Endo_Line = zeros(size(endocardium));
                Epi_Line = ones(size(epicardium));
                PosRoi = cat(1,epicardium,endocardium);
                LineRoi   = cat(1,Epi_Line,Endo_Line);
                Mask_Depth(:,:,cpt_slc) = griddata(PosRoi(:,1),PosRoi(:,2),LineRoi(:,1),Xq,Yq);


            end
            %%% Create a Depth Mask

        end




        function [epi, endo, LV_mask] = Spline_Segmentation(IM, nEpi_max, nEndo_max)
            % Cubic Spline Cardiac LV Segmentation
            %
            % SYNTAX [epicardium, endocardium] = spline_segmentation(IM, nEpi_max, nEndo_max)
            %
            % INPUTS:
            %   IM - 2D image matrix to be segmented
            %   nEpi_max - MAXIMUM number of spline nodes allowed around epicardium
            %   nEndo_max - MAXIMUM number of spline nodes allowed around endocardium
            %
            % OUTPUTS:
            %   epicardium - nx2 matrix of points generated from epicardium spline
            %   points now interpolated to 200 points (Modif KM)
            %
            %   endocardium - nx2 matrix of points generated from endocardium spline
            %   points now interpolated to 200 points (Modif KM)
            %
            %
            % Written by Eric Aliotta and Ilya Verzhbinsky, UCLA. 07/13/2016.
            % Modified by Kévin Moulin
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com
            clear 'hepi';
            clear 'hendo';

            figure('units','normalized','position',[0.156770833333333,0.040740740740741,0.577604166666667,0.769444444444444]);
            imagesc(IM); hold on; % here just view the image you want to base your borders on min(min(IM)) max(max(IM)) ,[0 nanmean(nanmean(IM))*5]
            title(gca,['Pick up to ' int2str(nEpi_max) ' points around the border around the epicardium']);
            colormap('jet')
            % caxis([0 4*nanmedian(nanmedian(IM))])
            epi_tmp = zeros(nEpi_max,2);

            for j = 1:nEpi_max

                h = impoint;
                epi_tmp(j,:) = getPosition(h);

                x = epi_tmp(1:j,1); y = epi_tmp(1:j,2);

                if j > 1
                    t = 1:j;
                    ts = 1:1/10:j;
                    xs = spline(t,x,ts);
                    ys = spline(t,y,ts);

                    if exist('hepi')
                        set(hepi,'Visible','off');
                    end
                    hepi = plot(xs,ys,'r');
                end

                dist = pdist([epi_tmp(j,:); epi_tmp(1,:)]);

                if j > 2
                    meandist_list = zeros(j, 1);
                    for k = 1:j
                        if k ~= j
                            dist_tmp = pdist([epi_tmp(k,:); epi_tmp(k+1,:)]);
                            meandist_list(k) = dist_tmp;
                        end
                    end
                    meandist = mean(meandist_list);
                    if dist < meandist
                        break
                    end
                end

            end
            nEpi = j;
            epi_tmp(nEpi+1:end, :) = [];

            % final spline
            t = 1:j+1;
            ts = 1:1/10:nEpi+1;
            x = epi_tmp([1:end,1],1); y = epi_tmp([1:end,1],2);
            xs = spline(t,x,ts);
            ys = spline(t,y,ts);

            set(hepi,'Visible','off');
            hepi = plot(xs,ys,'m');

            epicardium = [xs;ys]';

            endo_tmp = zeros(nEndo_max,2);

            title(gca,['Pick up to ' int2str(nEndo_max) ' points around the border around the endocardium']);

            for j = 1:nEndo_max

                h = impoint;
                endo_tmp(j,:) = getPosition(h);

                x = endo_tmp(1:j,1); y = endo_tmp(1:j,2);

                if j > 1
                    t = 1:j;
                    ts = 1:1/10:j;
                    xs = spline(t,x,ts);
                    ys = spline(t,y,ts);

                    if exist('hendo')
                        set(hendo,'Visible','off');
                    end
                    hendo = plot(xs,ys,'g');
                end

                dist = pdist([endo_tmp(j,:); endo_tmp(1,:)]);

                if j > 2
                    meandist_list = zeros(j, 1);
                    for k = 1:j
                        if k ~= j
                            dist_tmp = pdist([endo_tmp(k,:); endo_tmp(k+1,:)]);
                            meandist_list(k) = dist_tmp;
                        end
                    end
                    meandist = mean(meandist_list);
                    if dist < meandist
                        break
                    end
                end

            end

            nEndo = j;
            endo_tmp(nEndo+1:end, :) = [];

            % final spline
            t = 1:j+1;
            ts = 1:1/10:nEndo+1;
            x = endo_tmp([1:end,1],1); y = endo_tmp([1:end,1],2);
            xs = spline(t,x,ts);
            ys = spline(t,y,ts);

            set(hendo,'Visible','off');
            hendo = plot(xs,ys,'m');

            endocardium = [xs;ys]';

            pause;
            close;
            endo_mask = poly2mask(endocardium(:,1),endocardium(:,2),size(IM,1),size(IM,2));
            epi_mask = poly2mask(epicardium(:,1),epicardium(:,2),size(IM,1),size(IM,2));

            LV_mask = zeros(size(endo_mask));
            LV_mask = LV_mask + epi_mask - (epi_mask & endo_mask);

            xq=linspace(1,size(epicardium,1),200);
            yq=linspace(1,size(endocardium,1),200);
            epi(:,1) = interp1(epicardium(:,1),xq);
            epi(:,2) = interp1(epicardium(:,2),xq);
            endo(:,1) = interp1(endocardium(:,1),yq);
            endo(:,2) = interp1(endocardium(:,2),yq);
            return

        end

        function [Mask_AHA] = ROI2AHA_KM (Dcm, P_Endo, P_Epi,Mask)
            % Generate a mask matrix with 6 segments corresponding to the AHA cardiac segmentation
            %
            % SYNTAX:  [Mask_AHA] = ROI2AHA_KM (Mask, P_Endo, P_Epi)
            %
            % INPUTS:   Dcm - Image matrix
            %                 [y x slices]
            %
            %           P_Endo - List of Coordinates of the Endocardium ROI
            %
            %           P_Epi - List of Coordinates of the Endocardium ROI
            %
            %           Mask - LV Mask to format the AHA
            %
            % OUTPUTS:  Mask_AHA - Mask matrix
            %                 [y x slices AHA_segments]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            for cpt_slc=1:1:size(Dcm,3)
                figure (99)
                imagesc(Dcm(:,:,cpt_slc,1,1,1,1,1,1));
                title('Choose the jonction between RV/LV')
                [px py] = ginput(1);

                center=[ mean( P_Endo(:,1,cpt_slc) );mean( P_Endo(:,2,cpt_slc) )];
                center2=[ mean( P_Epi(:,1,cpt_slc) );mean( P_Epi(:,2,cpt_slc) )];
                Mask_AHA(:,:,cpt_slc,:) = DiffRecon_ToolBox.Divide_n_Rule(center,[px py], Mask(:,:,cpt_slc));% squeeze(Dcm(:,:,cpt_slc,1,1,1,1,1,1)));
                close(99)
            end

            Mask_AHA(Mask_AHA>0)=1;
        end


        function [Mask_AHA] = Divide_n_Rule(Center,VDVG, Mask)

            Mask_AHA = zeros(size(Mask,1), size(Mask,2) , 6);

            VectVDVG(1)=(VDVG(1)-Center(1));
            VectVDVG(2)=(VDVG(2)-Center(2));
            VectVDVG(3)=0;
            Mask_Tmp=[];
            for x = 1:1:size(Mask,2)
                for y = 1:1:size(Mask,1)
                    VectPix(1)=(x-Center(1));
                    VectPix(2)=(y-Center(2));
                    VectPix(3)=0;

                    % Unsigned angle between the two vectors
                    theta = acos(dot(VectVDVG / norm(VectVDVG), VectPix / norm(VectPix)));

                    % Determine the sign of the angle
                    sgn = sign(cross(VectVDVG, VectPix));

                    % Apply the sign and use mod to make it between 0 and 2*pi
                    Mask_Tmp(y,x) = mod(theta * (-1)^(sgn(3) < 0), 2*pi);

                    if  Mask_Tmp(y,x)>0 && 1*2*pi/6 >= Mask_Tmp(y,x)
                        Mask_AHA(y,x,1) = Mask(y,x);
                    elseif Mask_Tmp(y,x)>1*2*pi/6 && 2*2*pi/6 >= Mask_Tmp(y,x)
                        Mask_AHA(y,x,2) = Mask(y,x);
                    elseif Mask_Tmp(y,x)>2*2*pi/6 && 3*2*pi/6 >= Mask_Tmp(y,x)
                        Mask_AHA(y,x,3) = Mask(y,x);
                    elseif Mask_Tmp(y,x)>3*2*pi/6 && 4*2*pi/6 >= Mask_Tmp(y,x)
                        Mask_AHA(y,x,4) = Mask(y,x);
                    elseif Mask_Tmp(y,x)>4*2*pi/6 && 5*2*pi/6 >= Mask_Tmp(y,x)
                        Mask_AHA(y,x,5) = Mask(y,x);
                    else
                        Mask_AHA(y,x,6) = Mask(y,x);
                    end

                end
            end


        end
        function [ADC]= ADC_KM(Dcm, enum)
            %  Generate ADC maps: ADC= log(S/S0)/(b0-b) 
            %  Use the first b-value as the nDWI 
            %   
            % SYNTAX:  [ADC]= ADC_KM(Dcm, enum)
            %  
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %           
            %           enum - Structure which contains information about the dataset 
            %
            %          
            % OUTPUTS:  ADC - ADC image matrix (units [mm²/s])
            %                 [y x slices b-values directions averages dataset]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com
               
                
                ADC=[];
                disp('ADC calculation') 
                h = waitbar(0,'ADC calculation...');
                for cpt_set=1:1:enum.nset
                     for cpt_slc=1:1:enum.datasize(cpt_set).slc
                        for cpt_b=1:1:enum.datasize(cpt_set).b     
                          for cpt_dir=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).nb_dir           
                             for cpt_avg=1:1: enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dir(cpt_dir).nb_avg  
                                    if(cpt_b>1)
                                        ADC(:,:,cpt_slc,(cpt_b-1),cpt_dir,cpt_avg,cpt_set)=DiffRecon_ToolBox.ADCMap_local(squeeze(Dcm(:,:,cpt_slc,(cpt_b),cpt_dir,cpt_avg,cpt_set)),squeeze(Dcm(:,:,cpt_slc,1,1,1,cpt_set)),-enum.b(cpt_b));
                                    end
                            end
                         end
                       end
                       waitbar(cpt_slc/size(enum.slc,2),h);
                     end
                end
                close(h);    
            
            end

        function [ADC] = ADCMap_local(Vol,VolB0,b_vect)
        
        ADC=zeros(size(Vol,1),size(Vol,2));
        
        for y=1:1:size(Vol,1)
            for x=1:1:size(Vol,2)
                if VolB0(y,x)~=0 
        %             variables=[squeeze(VolB0(y,x)) squeeze(Vol(y,x,:))'];
        %             [p,S] = polyfit( b_vect,log((variables)),1);
        %             if p(1)>0
        %                 ADC(y,x) = 0; % D must not be <0 !!
        %                %disp('Fits on mean, read: D<0 set to 0')
        %             else
        %                 ADC(y,x) = -p(1);
        %             end
                    ADC(y,x)=log(Vol(y,x)/VolB0(y,x))/b_vect;
                else
                    ADC(y,x) = 0;
                end
            end
        end
        end

        function [Tensor, EigValue,EigVector,MD,FA,Trace_DTI]= Calc_Tensor_KM(varargin)
            % Generate a tensor from the DWI data for each slice each b-values
            % the first b-value is used as the nDWI reference for the tensor
            % calculation
            %
            % SYNTAX:  [Tensor, EigValue,EigVector,MD,FA,Trace_DTI]= Calc_Tensor_KM(Dcm, enum)
            %
            %
            % INPUTS:   Dcm - DWI image matrix
            %                 [y x slices b-values directions averages dataset]
            %
            %           enum - Structure which contains information about the dataset
            %
            %
            % OUTPUTS:  Tensor - Tensor image matrix
            %                 [y x slices b-values [xx xy xz; yx yy yz; zx zy zz]]
            %
            %           EigValue - Ordered EigValue image matrix
            %                 [y x slices b-values [EigV1 EigV2 EigV3]]
            %
            %           EigValue - Ordered EigVector image matrix
            %                 [y x slices b-values [x y z][EigVect1 EigVect2 EigVect3]]
            %
            %           MD - Mean Diffusivity from Tensor
            %                 [y x slices b-values]
            %
            %           FA - Fraction of anysotropy from Tensor
            %                 [y x slices b-values]
            %
            %           Trace_DTI - Trace image from Tensor
            %                 [y x slices b-values]
            %
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            Tensor=[];
            EigValue=[];
            EigVector=[];
            MD=[];
            FA=[];
            Trace_DTI=[];

            tmpInput=[];

            if numel(varargin) == 2
                Dcm=varargin{1};
                enum=varargin{2}(1);
                R=[1 0 0; 0 1 0; 0 0 1];

            elseif numel(varargin) == 3
                Dcm=varargin{1};
                enum=varargin{2}(1);
                R=varargin{3};
            else

            end

            disp('Tensor calculation')
            h = waitbar(0,'Tensor calculation...');
            for cpt_set=1:1:enum.nset
                for cpt_slc=1:1:enum.datasize(cpt_set).slc
                    for cpt_b=2:1:enum.datasize(cpt_set).b


                        tmpInput(:,:,1)=squeeze(Dcm(:,:,cpt_slc,1,1,1,cpt_set));
                        tmpInput(:,:,(2:enum.datasize.dir+1))=squeeze(Dcm(:,:,cpt_slc,cpt_b,:,1,cpt_set));
                        [tmp_Tensor,tmp_EigVector,tmp_EigValue, Mat] = DiffRecon_ToolBox.Tensor_local(tmpInput,enum.dataset(cpt_set).slc(cpt_slc).b(cpt_b).dirVector'*R,enum.b(cpt_b));

                        Tensor(:,:,cpt_slc,cpt_b-1,:)=tmp_Tensor;
                        EigVector(:,:,cpt_slc,cpt_b-1,:,:)=tmp_EigVector;
                        EigValue(:,:,cpt_slc,cpt_b-1,:)=tmp_EigValue;
                        [tmp_MD, tmp_FA, tmp_Trace] = DiffRecon_ToolBox.Maps_local(tmp_EigValue);
                        MD(:,:,cpt_slc,cpt_b-1)=tmp_MD;
                        FA(:,:,cpt_slc,cpt_b-1)=tmp_FA;
                        Trace_DTI(:,:,cpt_slc,cpt_b-1)=tmp_Trace;

                    end
                    waitbar(cpt_slc/enum.datasize(cpt_set).slc,h);
                end

            end
            close(h);

        end

        function [Tensor,EigVector,EigValue, Mat2] = Tensor_local(slice,dir,bvalue)
            % slice : x y [B0 B1-dir1 B2-dir2...]
            % dir : x1 y1 z1
            %       x2 y2 z2
            %        .  .  .
            %        .  .  .
            %
            %  Tensor : x y [6]
            %  EigVector : x y [3 coor][3 num]
            %  EigValue : x y [3]


            nb_dir=size(dir,1);
            H = zeros(nb_dir,6);

            for i=1:nb_dir
                H(i,:)=[dir(i,1)*dir(i,1),dir(i,2)*dir(i,2),dir(i,3)*dir(i,3),2*dir(i,1)*dir(i,2),2*dir(i,1)*dir(i,3),2*dir(i,2)*dir(i,3)];
            end
            [U,S,V] = svd(H,0);
            H_inv=V*inv(S)*U';                 %H is a 6*30 matrix



            Tensor=zeros(size(slice,1),size(slice,2),6);
            EigVector=zeros(size(slice,1),size(slice,2),3,3);
            EigValue= zeros(size(slice,1),size(slice,2),3);
            Mat=zeros(size(slice,1),size(slice,2),1,9);
            Mat2=zeros(size(slice,1),size(slice,2),3,3);
            for y=1:1:size(slice,1)
                for x=1:1:size(slice,2)
                    Y=[];

                    if slice(y,x,1)~=0
                        for z=1:1:nb_dir
                            if double(slice(y,x,z+1))~=0
                                Y=[Y;log(double(slice(y,x,1))/double(slice(y,x,z+1)))/bvalue]; % Y = [log(S0/S1), log(S0/S2), log(S0,S3)....]
                            else
                                Y=[Y;0]; % Y = [log(S0/S1), log(S0/S2), log(S0,S3)....]
                            end
                        end
                        Tensor(y,x,:)=H_inv*Y;
                        Mat=[Tensor(y,x,1),Tensor(y,x,4),Tensor(y,x,5);Tensor(y,x,4),Tensor(y,x,2),Tensor(y,x,6);Tensor(y,x,5),Tensor(y,x,6),Tensor(y,x,3)];
                        if mean(mean(isnan(Mat)))>0 || mean(mean(isinf(Mat)))>0
                            Mat=zeros(3,3);
                            % Mat2(y,x,1,:)=[0;0;0;0;0;0;0;0;0];
                        end
                        Mat2(y,x,:,:)=Mat;

                        [Vect,Diag]=eig(Mat);

                        % EigVector(x,y,:,:)=Vect;

                        %EigValue(y,x,:)=[abs(Diag(1,1)/bvalue),abs(Diag(2,2)/bvalue),abs(Diag(3,3)/bvalue)];
                        EigValue(y,x,:)=[abs(Diag(1,1)),abs(Diag(2,2)),abs(Diag(3,3))];


                        % if((EigValue(y,x,1)<0)&&(EigValue(y,x,2)<0)&&(EigValue(y,x,3)<0)), EigValue(y,x,:)=abs(EigValue(y,x,:));end
                        % if(EigValue(y,x,1)<=0), EigValue(y,x,1)=eps; end
                        % if(EigValue(y,x,2)<=0), EigValue(y,x,2)=eps; end

                        [t,index]=sort(EigValue(y,x,:),'descend');
                        EigValue(y,x,:)=EigValue(y,x,index);
                        EigVector(y,x,:,:)=Vect(:,index);
                    else
                        Mat2(y,x,:,:)=0;
                        Tensor(y,x,:)=0;
                        EigValue(y,x,:)=0;
                        EigVector(y,x,:,:)=0;
                    end

                end
            end
            %WriteInrTensorData_KM(Mat2, [1 1 1], 'tensor');
        end
        function [Tensor,EigVector,EigValue, Mat2] = Tensor_local_ls(slice,dir,bvalue)

            % Construct Bmatrix
            for i=1:size(dir,1)
                BB(i,:)=[dir(i,1)*dir(i,1),dir(i,2)*dir(i,2),dir(i,3)*dir(i,3),2*dir(i,1)*dir(i,2),2*dir(i,1)*dir(i,3),2*dir(i,2)*dir(i,3)]*bvalue;
            end


            for y=1:1:size(slice,1)
                for x=1:1:size(slice,2)
                    % Construct log signal
                    SS=squeeze([log(double(slice(y,x,1))/double(slice(y,x,2:end)))]);

                    % Least Square fitting
                    Tensor(y,x,:) = lsqr(-BB,SS);
                    Mat=[Tensor(y,x,1),Tensor(y,x,4),Tensor(y,x,5);Tensor(y,x,4),Tensor(y,x,2),Tensor(y,x,6);Tensor(y,x,5),Tensor(y,x,6),Tensor(y,x,3)];

                    % Eigen decomposition
                    [Vect,Diag]=eig(Mat);
                    EigValue(y,x,:)=[abs(Diag(1,1)),abs(Diag(2,2)),abs(Diag(3,3))];
                    [t,index]=sort(EigValue(y,x,:),'descend');

                    % Save the Results
                    Mat2(y,x,:,:)=Mat;
                    EigValue(y,x,:)=EigValue(y,x,index);
                    EigVector(y,x,:,:)=Vect(:,index);
                end
            end


        end
        function [ADC, FA, TRACE, I1, I2, I3] = Maps_local(EigValue)

            ADC=zeros(size(EigValue,1),size(EigValue,2));
            FA=zeros(size(EigValue,1),size(EigValue,2));
            TRACE=zeros(size(EigValue,1),size(EigValue,2));
            I1=zeros(size(EigValue,1),size(EigValue,2));
            I2=zeros(size(EigValue,1),size(EigValue,2));
            I3=zeros(size(EigValue,1),size(EigValue,2));

            for y=1:1:size(EigValue,1)
                for x=1:1:size(EigValue,2)
                    TRACE(y,x)=EigValue(y,x,1)+EigValue(y,x,2)+EigValue(y,x,3);
                    ADC(y,x)=(EigValue(y,x,1)+EigValue(y,x,2)+EigValue(y,x,3))/3;
                    FA(y,x)=sqrt((3*((EigValue(y,x,1)-ADC(y,x))^2+(EigValue(y,x,2)-ADC(y,x))^2+(EigValue(y,x,3)-ADC(y,x))^2))/(2*(EigValue(y,x,1)^2+EigValue(y,x,2)^2+EigValue(y,x,3)^2)));

                    I1(y,x)=EigValue(y,x,1)+EigValue(y,x,2)+EigValue(y,x,3);
                    I2(y,x)=EigValue(y,x,1)*EigValue(y,x,2)+EigValue(y,x,2)*EigValue(y,x,3)+EigValue(y,x,1)*EigValue(y,x,3);
                    I3(y,x)=EigValue(y,x,1)*EigValue(y,x,2)*EigValue(y,x,3);

                end
            end
        end
        function [HA TRA E2A RAD_s CIR_s LON_s]= HA_E2A_KM( EigVect1, EigVect2, Mask, P_Epi, P_Endo)
            % Calculates the angle (degrees) between the primary eigenvector and the SA
            % plane; epicardium and endocardium should be a series of points representing the
            % boundaries of the myocardium.
            %
            % SYNTAX:  HA_KM(  EigVect1, Mask, P_Epi, P_Endo)
            %
            % INPUTS:   EigVect1 - First EigVector image matrix
            %                 [y x slices coordinates]
            %
            %           Mask -  Mask matrix
            %                 [y x slices]
            %
            %           P_Endo - List of Coordinates of the Endocardium ROI
            %
            %           P_Epi - List of Coordinates of the Endocardium ROI
            %
            % OUTPUTS:  HA - HA image matrix (units [- pi pi])
            %                 [y x slices]
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com






            %% using ellipses

            yres = size(EigVect1,1);   xres = size(EigVect1,2);
            [Xq,Yq] = meshgrid(1:xres,1:yres);

            P_Epi=P_Epi(1:end-2,:,:);
            P_Endo=P_Endo(1:end-2,:,:);

            npts = size(P_Epi,1);
            npts2 = size(P_Endo,1);




            %%

            disp('Generate HA')
            h = waitbar(0,'Generate HA...');
            E2A = zeros(size(Mask,1),size(Mask,2),size(Mask,3));
            HA = zeros(size(Mask,1),size(Mask,2),size(Mask,3));
            TRA = zeros(size(Mask,1),size(Mask,2),size(Mask,3));

            RAD_s=zeros(size(Mask,1),size(Mask,2),size(Mask,3),3);
            CIR_s=zeros(size(Mask,1),size(Mask,2),size(Mask,3),3);
            LON_s=zeros(size(Mask,1),size(Mask,2),size(Mask,3),3);
            FLIP_s= zeros(size(Mask,1),size(Mask,2),size(Mask,3),3);


            for z=1:size(Mask,3)
                if ~isnan(mean(mean(Mask(:,:,z),1),2))
                    Vec = zeros(npts,2);
                    Vec2 = zeros(npts2,2);
                    positions=[];
                    vectors=[];


                    Vec(1,:) = P_Epi(1,:,z) - P_Epi(end,:,z);
                    for y = 2:npts
                        Vec(y,:) = P_Epi(y,:,z) - P_Epi(y-1,:,z);
                    end

                    Vec2(1,:) = P_Endo(1,:,z) - P_Endo(end,:,z);
                    for y = 2:npts2
                        Vec2(y,:) = P_Endo(y,:,z) - P_Endo(y-1,:,z);
                    end

                    positions = cat(1,P_Epi(:,:,z),P_Endo(:,:,z));
                    vectors   = cat(1,Vec,Vec2);



                    Vy = griddata(positions(:,1),positions(:,2),vectors(:,2),Xq,Yq);
                    Vx = griddata(positions(:,1),positions(:,2),vectors(:,1),Xq,Yq);


                    for y = 1:yres
                        for x = 1:xres
                            if Mask(y,x,z) ~= 0 & ~isnan(Mask(y,x,z))


                                %                 if squeeze(EigVect1(y,x,z,3))>0
                                %                     Fiber_vect = squeeze(EigVect1(y,x,z,:));
                                %                 else
                                %                     Fiber_vect = -squeeze(EigVect1(y,x,z,:));
                                %                 end

                                E1 = squeeze(EigVect1(y,x,z,:));
                                E1= E1./norm(E1);
                                E2 = squeeze(EigVect2(y,x,z,:));

                                % Circunferiential Vector definition
                                Circ = [Vx(y,x) Vy(y,x) 0];
                                Circ= Circ./norm(Circ);
                                % Longitudinal Vector definition
                                Long= [0 0 1];

                                % Projection of the Fiber Vector onto the Circunferential
                                % direction
                                E1proj=dot(E1,Circ)*Circ/(norm(Circ)^2);
                                Fiber_proj=[E1proj(1) E1proj(2) E1(3)];

                                Fiber_proj=Fiber_proj./norm(Fiber_proj);


                                %HA(y,x,z) = atan2(Fiber_proj(3), norm([E1proj(1) E1proj(2) 0]))*180/(pi);
                                HA(y,x,z) = asin(Fiber_proj(3)/norm(Fiber_proj))*180/(pi);


                                % Radial Vector definition
                                Rad=cross(Circ/norm(Circ),Long/norm(Long));

                                MidFiber=cross(Fiber_proj/norm(Fiber_proj),Rad/norm(Rad));
                                %MidFiber=cross(E1/norm(E1),Rad/norm(Rad));

                                % Projection of the Sheet Vector onto the Radial
                                % direction
                                E2proj=dot(E2,Rad)*Rad/(norm(Rad)^2);

                                % Projection of the Sheet Vector onto the MidFiber
                                % direction
                                tProj3=dot(E2,MidFiber)*MidFiber/(norm(MidFiber)^2);


                                E2A(y,x,z) = atan2(norm(E2proj),norm(tProj3))*180/(pi);



                                %[vect_proj]= proj_local_KM( Fiber_vect, tang);
                                %HA(y,x,z)= proj_local_KM( Fiber_vect, tang);
                                vect2 = [squeeze(EigVect1(y,x,z,1)) squeeze(EigVect1(y,x,z,2)) 0];
                                TRA(y,x,z)= acos(dot(vect2,Circ)/(norm(Circ)*norm(vect2)))*180/(pi);



                                % TRA(y,x,z) = asin(zComp/hyp)*180/(pi);

                                RAD_s(y,x,z,:)=Rad;
                                CIR_s(y,x,z,:)=Circ;
                                LON_s(y,x,z,:)=Long;
                                FLIP_s(y,x,z,:)=Fiber_proj;
                                %                test(y,x,z)=dot(tang,tProj);

                                %tang = [Vx(y,x) Vy(y,x) 0];
                                if dot(Fiber_proj  ,Circ) <0 % || dot(Fiber_proj,Long) > 0%dot(Circ,(E1)) < 0   %
                                    HA(y,x,z) = -HA(y,x,z);
                                    %  FLIP_s(y,x,z)=1;
                                end

                                %                   if abs(Rad(2))>abs(Rad(1))
                                %                     HA(y,x,z) = -HA(y,x,z);
                                %                     FLIP_s(y,x,z)=1;
                                %                   end

                                if dot(vect2,Circ) < 0 %&& HA(j,k) > 0
                                    TRA(y,x,z) = TRA(y,x,z)-180;
                                end
                            end
                        end
                    end
                end
                waitbar(z/size(Mask,3),h);
            end
            close(h)
        end

        function [HA_filter]= HA_Filter_KM(HA, LV_mask, Mask_Depth,display)
            % Filter the HA to negative HA angles transmurally 
            % this function doesn't modify the HA distribution just inver the angles
            %
            % SYNTAX:  HA_Filter_KM(HA, LV_mask, Mask_Depth,display)
            %
            % INPUTS:   HA - HA image matrix (units [- pi pi])
            %                 [y x slices]
            %
            %           LV_mask -  Left Ventricle Mask matrix
            %                 [y x slices]
            %
            %           Mask_Depth -  Transmural Depth Mask matrix
            %                 [y x slices]
            %
            %           display - bool to display the result of the filter
            %
            % OUTPUTS:  HA_filter - filtered HA image matrix (units [- pi pi])
            %                 [y x slices]
            %
            % Kevin Moulin 04.17.2024
            % Kevin.Moulin@cardio.chboston.org
            % Kevin.Moulin.26@gmail.com

            HA_filter=HA;

            Local_mask=LV_mask;

            ListHA=HA(Local_mask>0);

            [row,col] = find(Local_mask>0);
            ListDist=Mask_Depth(Local_mask>0);

            ListDist(isnan(ListHA))=nan;
            ListHA(isnan(ListDist))=nan;
            % n=find(isnan(ListHA));

            if display
                figure
                scatter(ListDist,ListHA,[],'r','filled');
                axis([0 1 -1.2*100 1.2*100])
                set(gca,'XTick',[0 0.25 0.5 0.75 1]);
                set(gca,'XTickLabel',{'ENDO','','MID','','EPI'});
                set(gca,'YTick',[-90 -45 0 45 90]);

                xlabel('')
                ylabel('HA(°)')
                set(gca, 'box', 'off') % remove top x-axis and right y-axis
                set(gcf, 'color', [1 1 1]);
                set(gca, 'color', [1 1 1]);
                ax = gca;
                ax.XColor = 'black';
                ax.YColor = 'black';
                ax.FontSize=15;
                ax.FontWeight='bold';

                legend('off');
                grid off
            end


            %row(n)=[];
            %col(n)=[];
            ListDist2=ListDist;
            ListHA2=ListHA;

            ListDist2(isnan(ListDist))=[];
            ListHA2(isnan(ListHA))=[];

            %% HA has to be flipped
            if nanmedian(ListHA2(find(ListDist2<0.1)))<0
                ListHA=-ListHA;
            end

            f = fittype('a*x+b');
            fit1 = fit(ListDist2,ListHA2,f,'StartPoint',[1 1]);
            fdata = feval(fit1,ListDist);
            I = abs(fdata - ListHA) > 1.5*nanstd(ListHA);
            outliers = excludedata(ListDist,ListHA,'indices',I);

            if display
                figure
                scatter(ListDist(~outliers),ListHA(~outliers),[],'r','filled');
                hold on
                scatter(ListDist(outliers),ListHA(outliers),[],'m','filled');
                plot(ListDist,fdata,'-k','LineWidth',4)
                plot((0:0.01:1),fit1(0:0.01:1)+1.5*nanstd(ListHA),':k','LineWidth',4)
                plot((0:0.01:1),fit1(0:0.01:1)-1.5*nanstd(ListHA),':k','LineWidth',4)
                axis([0 1 -1.2*100 1.2*100])
                set(gca,'XTick',[0 0.25 0.5 0.75 1]);
                set(gca,'XTickLabel',{'ENDO','','MID','','EPI'});
                set(gca,'YTick',[-90 -45 0 45 90]);

                xlabel('')
                ylabel('HA(°)')
                set(gca, 'box', 'off') % remove top x-axis and right y-axis
                set(gcf, 'color', [1 1 1]);
                set(gca, 'color', [1 1 1]);
                ax = gca;
                ax.XColor = 'black';
                ax.YColor = 'black';
                ax.FontSize=15;
                ax.FontWeight='bold';


                legend('off');
                grid off
            end
            ListOutliers=ListHA(outliers);
            ListDistOutliers=ListDist(outliers);
            ListOutliers(ListDistOutliers<0.5&ListOutliers<0)=-ListOutliers(ListDistOutliers<0.5&ListOutliers<0);
            ListOutliers(ListDistOutliers>0.5&ListOutliers>0)=-ListOutliers(ListDistOutliers>0.5&ListOutliers>0);
            ListHA(outliers)=ListOutliers;

            if display
                figure
                scatter(ListDist(~outliers),ListHA(~outliers),[],'r','filled');
                hold on
                scatter(ListDist(outliers),ListHA(outliers),[],'m','filled');
                axis([0 1 -1.2*100 1.2*100])
                set(gca,'XTick',[0 0.25 0.5 0.75 1]);
                set(gca,'XTickLabel',{'ENDO','','MID','','EPI'});
                set(gca,'YTick',[-90 -45 0 45 90]);

                xlabel('')
                ylabel('HA(°)')
                set(gca, 'box', 'off') % remove top x-axis and right y-axis
                set(gcf, 'color', [1 1 1]);
                set(gca, 'color', [1 1 1]);
                ax = gca;
                ax.XColor = 'black';
                ax.YColor = 'black';
                ax.FontSize=15;
                ax.FontWeight='bold';

                legend('off');
                grid off
            end
            HA_filter(sub2ind(  size(HA_filter), row,col))=ListHA;

        end




    end
end