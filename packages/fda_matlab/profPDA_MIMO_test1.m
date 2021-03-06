%  ----------------------------------------------------------
%          Coupled exponential decays without forcing
%  ----------------------------------------------------------

T = 4;
range = [0,T];

%  set up uncoupled coefficient matrix

Amat1 = [-1, 0; 0, -2];

yinit = [1, 1]';

[t1, y1] = ode45(@oscillate, range, yinit, [], Amat1);

figure(1)
subplot(1,1,1)
plot(t1, y1)

%  set up coefficient matrix

Amat2 = [-1, -.5; -1, -2];

yinit = [1, 1]';

[t2, y2] = ode45(@oscillate, range, yinit, [], Amat2);

figure(2)
subplot(1,1,1)
plot(t2, y2)
hold on
plot(t1, y1, '--')
hold off

%  set up quadrature points and weights

nquad = 401;
quadpts = [linspace(0,T,nquad)'];
quadwts = ones(nquad,1);
quadwts(2:2:nquad-1) = 4;
quadwts(3:2:nquad-2) = 2;
quadwts = (T/(nquad-1)).*quadwts./3;
quadvals = [quadpts, quadwts];

%  basis for fitting the data

%  first bspline basis

norder = 5;
nbasis = norder + 14;
basisobj1 = create_bspline_basis(range, nbasis, norder);

basisobj1 = putquadvals(basisobj1, quadvals);

for ideriv=0:1
    basisvalues = eval_basis(quadpts, basisobj1, ideriv);
    values{ideriv+1} = basisvalues.*(sqrt(quadwts)*ones(1,nbasis));
end

basisobj1 = putvalues(basisobj1, values);

%  second bspline basis

norder = 5;
nbasis = norder + 14;
basisobj2 = create_bspline_basis(range, nbasis, norder);

basisobj2 = putquadvals(basisobj2, quadvals);

for ideriv=0:1
    basisvalues = eval_basis(quadpts, basisobj2, ideriv);
    values{ideriv+1} = basisvalues.*(sqrt(quadwts)*ones(1,nbasis));
end

basisobj2 = putvalues(basisobj2, values);

%  exponential basis

nbasis = 2;
tau = [-1, -2];
basisobj1 = create_exponential_basis(range, nbasis, tau);
basisobj1 = putquadvals(basisobj1, quadvals);
for ideriv=0:1
    basisvalues = eval_basis(quadpts, basisobj1, ideriv);
    values{ideriv+1} = basisvalues.*(sqrt(quadwts)*ones(1,nbasis));
end
basisobj1 = putvalues(basisobj1, values);

basisobj2 = basisobj1;

%  set up a fine mesh of values

nfine = 101;
tfine = linspace(0, T, nfine)';

%  smooth numerical solution using basis

t = t1;
y = y1;

t = t2;
y = y2;

indx = 1;
indy = 2;
xfd = smooth_basis(t, y(:,indx), basisobj1);
yfd = smooth_basis(t, y(:,indy), basisobj2);

subplot(2,1,1)
plotfit_fd(y(:,indx), t, xfd);
subplot(2,1,2)
plotfit_fd(y(:,indy), t, yfd);

%  set up values over TFINE

xvec0 = eval_fd(tfine, xfd);
yvec0 = eval_fd(tfine, yfd);

%  add some noise

sigma = 0.1;
xvec = xvec0 + randn(nfine,1).*sigma;
yvec = yvec0 + randn(nfine,1).*sigma;

%  set up matrices required for profPDA_MIM0

basismat1 = eval_basis(tfine, basisobj1);
Bmat1 = basismat1'*basismat1;
Dmat1 = basismat1'*xvec;

basismat2 = eval_basis(tfine, basisobj2);
Bmat2 = basismat2'*basismat2;
Dmat2 = basismat2'*yvec;

%  set up constant basis for weight functions

bbasis = create_constant_basis([0,T]);

bbasis = putquadvals(bbasis, quadvals);

bbasisvalues = eval_basis(quadpts, bbasis);
bvalues{1} = bbasisvalues;

bbasis = putvalues(bbasis, bvalues);

%  set up BWTCELL
%  All coefficients for function are estimated.
%  All coefficients for first derivative are not.
%  True values are -1, 0, 0, -1

bwtcell1{1,1} = fdPar(fd(0, bbasis),0,0,1);
bwtcell1{2,1} = fdPar(fd(0, bbasis),0,0,1);

bwtcell2{1,1} = fdPar(fd(0, bbasis),0,0,1);
bwtcell2{2,1} = fdPar(fd(0, bbasis),0,0,1);

%  struct object for first fitcell

fitstruct1.y = xvec;
fitstruct1.basisobj = basisobj1;
fitstruct1.basismat = basismat1;
fitstruct1.Bmat = Bmat1;
fitstruct1.Dmat = Dmat1;
fitstruct1.bwtcell = bwtcell1;
fitstruct1.awtcell = {};
fitstruct1.ufdcell = {};
fitstruct1.Dorder  = 1;

%  struct object for second fitcell

fitstruct2.y = yvec;
fitstruct2.basisobj = basisobj2;
fitstruct2.basismat = basismat2;
fitstruct2.Bmat = Bmat2;
fitstruct2.Dmat = Dmat2;
fitstruct2.bwtcell = bwtcell2;
fitstruct2.awtcell = {};
fitstruct2.ufdcell = {};
fitstruct2.Dorder  = 1;

% set values of smoothing parameter

lambda = 1e1;
fitstruct1.lambda = lambda;
fitstruct2.lambda = lambda;

%  define FITCELL

fitcell{1} = fitstruct1;
fitcell{2} = fitstruct2;

gradwrd = 1;

bvectru = [1, 0.5, 1, 2]';  %  initial values for unforced example

bvec0 = bvectru;

%  check solution at BVEC0

[PENSSE, DPENSSE, PEN, coefcell, fitcellout, penmatcell] = ...
                 profPDA_MIMO(bvec0, fitcell, gradwrd);
             
%  plot fit

fdobj1 = fd(coefcell{1}, basisobj1);
fdobj2 = fd(coefcell{2}, basisobj2);

subplot(2,1,1)
plotfit_fd(xvec, tfine, fdobj1)
subplot(2,1,2)
plotfit_fd(yvec, tfine, fdobj2)

PENSSE

%  check derivs of solution at BVEC0

bvec0 = bvectru;
[PENSSE, DPENSSEPEN, PEN] = profPDA_MIMO(bvec0, fitcell, 1);

DPENHAT = zeros(1,4);
for j=1:4
    bvecj = bvec0;
    bvecj(j) = bvecj(j) + 0.0001;
    PENSSEj = profPDA_MIMO(bvecj, fitcell, 0);
    DPENHAT(j) = (PENSSEj - PENSSE)/0.0001;
end

[DPENSSE; DPENHAT]


    
    
%  set up options for FMINUNC

options = optimset('LargeScale', 'off',  ...
                   'Display',    'iter', ...
                   'MaxIter',    20,     ...
                   'GradObj',    'on',  ...
                   'TolFun',     1e-5,   ...
                   'TolCon',     1e-5,   ...
                   'TolX',       1e-5,   ...
                   'TolPCG',     1e-5);

gradwrd = 1;

% optimize the fit

bvec0 = bvectru;  %  initial values for unforced example
bvec0 = zeros(4,1);

[bvec, fval, exitflag, output, grad] = ...
            fminunc(@profPDA_MIMO, bvec0, options, ...
                    fitcell, gradwrd);

bvec

[PENSSE, DPENSSE, PEN, coefcell, fitcellout] = ...
                 profPDA_MIMO(bvec, fitcell, gradwrd);

fdobj1 = fd(coefcell{1}, basisobj1);
fdobj2 = fd(coefcell{2}, basisobj2);

subplot(2,1,1)
plotfit_fd(xvec, tfine, fdobj1)
subplot(2,1,2)
plotfit_fd(yvec, tfine, fdobj2)

PENSSE

DPENSSE

%  ----------------------------------------------------------
%        Coupled exponential decays with step forcing
%  ----------------------------------------------------------

T = 8;
range = [0,T];

%  set up coefficient matrix

Amat = [-1, -.5; -1, -2];

yinit = [1, 1]';

[t, y] = ode45(@oscillate, range, yinit, [], Amat, 4);

subplot(1,1,1)
plot(t, y)

%  set up quadrature points and weights

nquad = 801;
quadpts = [linspace(0,T,nquad)'];
quadwts = ones(nquad,1);
quadwts(2:2:nquad-1) = 4;
quadwts(3:2:nquad-2) = 2;
quadwts = (T/(nquad-1)).*quadwts./3;
quadvals = [quadpts, quadwts];

%  basis for fitting the data

%  first bspline basis

norder = 5;
breaks = [0:0.5:4,4,4,4:0.5:8];
nbasis = length(breaks) + norder - 2;
basisobj1 = create_bspline_basis(range, nbasis, norder, breaks);

basisobj1 = putquadvals(basisobj1, quadvals);

for ideriv=0:1
    basisvalues = eval_basis(quadpts, basisobj1, ideriv);
    values{ideriv+1} = basisvalues.*(sqrt(quadwts)*ones(1,nbasis));
end

basisobj1 = putvalues(basisobj1, values);

basisobj2 = basisobj1;

%  set up a fine mesh of values

nfine = 101;
tfine = linspace(0, T, nfine)';

%  smooth numerical solution using basis

indx = 1;
indy = 2;
xfd = smooth_basis(t, y(:,indx), basisobj1);
yfd = smooth_basis(t, y(:,indy), basisobj2);

subplot(2,1,1)
plotfit_fd(y(:,indx), t, xfd);
subplot(2,1,2)
plotfit_fd(y(:,indy), t, yfd);

%  set up values over TFINE

xvec0 = eval_fd(tfine, xfd);
yvec0 = eval_fd(tfine, yfd);

%  add some noise

sigma = 0.1;
xvec = xvec0 + randn(nfine,1).*sigma;
yvec = yvec0 + randn(nfine,1).*sigma;

%  set up matrices required for profPDA_MIM0

basismat1 = eval_basis(tfine, basisobj1);
Bmat1 = basismat1'*basismat1;
Dmat1 = basismat1'*xvec;

basismat = eval_basis(tfine, basisobj2);
Bmat = basismat'*basismat;
Dmat = basismat'*yvec;

%  set up constant basis for weight functions

bbasis = create_constant_basis([0,T]);

bbasis = putquadvals(bbasis, quadvals);

bbasisvalues = eval_basis(quadpts, bbasis);
bvalues{1} = bbasisvalues;

bbasis = putvalues(bbasis, bvalues);

%  set up BWTCELL
%  All coefficients for function are estimated.
%  All coefficients for first derivative are not.
%  True values are -1, 0, 0, -1

bwtcell1{1,1} = fdPar(fd(0, bbasis),0,0,1);
bwtcell1{2,1} = fdPar(fd(0, bbasis),0,0,1);

bwtcell2{1,1} = fdPar(fd(0, bbasis),0,0,1);
bwtcell2{2,1} = fdPar(fd(0, bbasis),0,0,1);

abasis = bbasis;
awtcell1{1} = fdPar(fd(0, abasis), 0, 0, 1);
awtcell2{1} = fdPar(fd(0, abasis), 0, 0, 1);

ubasis = create_bspline_basis(range, 2, 1, [0,4,8]);
ufdcell{1} = fd([0;1],ubasis);

%  struct object for first fitcell

fitstruct1.y = xvec;
fitstruct1.basisobj = basisobj1;
fitstruct1.basismat = basismat1;
fitstruct1.Bmat = Bmat1;
fitstruct1.Dmat = Dmat1;
fitstruct1.bwtcell = bwtcell1;
fitstruct1.awtcell = awtcell1;
fitstruct1.ufdcell = ufdcell;
fitstruct1.Dorder  = 1;

%  struct object for second fitcell

fitstruct.y = yvec;
fitstruct.basisobj = basisobj2;
fitstruct.basismat = basismat;
fitstruct.Bmat = Bmat;
fitstruct.Dmat = Dmat;
fitstruct.bwtcell = bwtcell2;
fitstruct.awtcell = awtcell2;
fitstruct.ufdcell = ufdcell;
fitstruct.Dorder  = 1;

% set values of smoothing parameter

lambda = 1e1;
fitstruct1.lambda = lambda;
fitstruct.lambda = lambda;

%  define FITCELL

fitcell{1} = fitstruct1;
fitcell{2} = fitstruct;

gradwrd = 0;

bvectru = [1, 0.5, 1, 1, 2, 1]';  %  initial values for unforced example

bvec0 = bvectru;

%  get derivatives

gradwrd = 1;

[penmatcell, Dpenmatcell] = eval_Rsm(npar, fitcell, gradwrd);

for ivar=1:2
    Dpenmatstructi = Dpenmatcell{ivar};
    disp(ivar)
    disp('Smat')
    DSarray = Dpenmatstructi.DSmat;
    for jvar=1:2
        disp(DSarray(:,:,jvar));
        jind = (ivar-1)*2+jvar;
        bvecj = bvec0;
        bvecj(jind) = bvecj(jind) + 0.0001;
        [fitcellj, npar] = bvec2fitcell(bvecj, fitcell);
        penmatcellj = eval_Rsm(npar, fitcellj, 0);
        penmatstructj = penmatcellj{ivar};
        Smatj = penmatstructj.Smat;
        penmatstruct = penmatcell{ivar};
        Smat0 = penmatstruct.Smat;
        DSmatj = (Smatj-Smat0)./0.0001;
        disp(DSmatj);
    end
    disp('Tmat')
    DTarray = Dpenmatstructi.DTmat;
    for jvar=1:2
        disp(DTarray(:,:,jvar));
        jind = (ivar-1)*2+jvar;
        bvecj = bvec0;
        bvecj(jind) = bvecj(jind) + 0.0001;
        [fitcellj, npar] = bvec2fitcell(bvecj, fitcell);
        penmatcellj = eval_Rsm(npar, fitcellj, 0);
        penmatstructj = penmatcellj{ivar};
        Tmatj = penmatstructj.Tmat;
        penmatstruct = penmatcell{ivar};
        Tmat0 = penmatstruct.Tmat;
        DTmatj = (Tmatj-Tmat0)./0.0001;
        disp(DTmatj);
    end
end

%  check solution at BVEC0

[PENSSE, DPENSSE, PEN, coefcell, fitcellout, penmatcell] = ...
                 profPDA_MIMO(bvec0, fitcell, gradwrd);
             
%  plot fit

fdobj1 = fd(coefcell{1}, basisobj1);
fdobj2 = fd(coefcell{2}, basisobj2);

subplot(2,1,1)
plotfit_fd(xvec, tfine, fdobj1)
subplot(2,1,2)
plotfit_fd(yvec, tfine, fdobj2)

PENSSE

%  check derivs of solution at BVEC0

bvec0 = bvectru;
[PENSSE, DPENSSEPEN, PEN] = profPDA_MIMO(bvec0, fitcell, 1);

DPENHAT = zeros(1,6);
for j=1:6
    bvecj = bvec0;
    bvecj(j) = bvecj(j) + 0.0001;
    PENSSEj = profPDA_MIMO(bvecj, fitcell, 0);
    DPENHAT(j) = (PENSSEj - PENSSE)/0.0001;
end

[DPENSSE; DPENHAT]
    
%  set up options for FMINUNC

options = optimset('LargeScale', 'off',  ...
                   'Display',    'iter', ...
                   'MaxIter',    20,     ...
                   'GradObj',    'on',  ...
                   'TolFun',     1e-5,   ...
                   'TolCon',     1e-5,   ...
                   'TolX',       1e-5,   ...
                   'TolPCG',     1e-5);

gradwrd = 1;

% optimize the fit

bvec0 = bvectru;  %  initial values for unforced example

[bvec, fval, exitflag, output, grad] = ...
            fminunc(@profPDA_MIMO, bvec0, options, ...
                    fitcell, gradwrd);

bvec

[PENSSE, DPENSSE, PEN, coefcell, fitcellout] = ...
                 profPDA_MIMO(bvec, fitcell, gradwrd);

fdobj1 = fd(coefcell{1}, basisobj1);
fdobj2 = fd(coefcell{2}, basisobj2);

subplot(2,1,1)
plotfit_fd(xvec, tfine, fdobj1)
subplot(2,1,2)
plotfit_fd(yvec, tfine, fdobj2)

PENSSE

DPENSSE

