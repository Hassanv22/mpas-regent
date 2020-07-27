import "regent"

local cio = terralib.includec("stdio.h")
local clib = terralib.includec("stdlib.h")

terralib.linklibrary("/share/software/user/open/netcdf/4.4.1.1/lib/libnetcdf.so")
local netcdf = terralib.includec("/share/software/user/open/netcdf/4.4.1.1/include/netcdf.h")

local nCells = 2562
local nEdges = 7680
local nVertices = 5120
local maxEdges = 10
local maxEdges2 = 20
local TWO = 2
local vertexDegree = 3
local nVertLevels = 1

local FILE_NAME = "x1.2562.grid.nc"

-----------------------------------------------
------- FIELD SPACES FOR MESH ELEMENTS --------
-----------------------------------------------


--a hexagonal/primal cell (aka cell)
fspace P_i {
    cellID : int,
    lat : double,
    lon : double,
    x : double,
    y : double,
    z : double,
    meshDensity : double,
    nEdgesOnCell : int,
    areaCell : double,
    edgesOnCell : int[maxEdges],
    cellsOnCell : int[maxEdges],
    verticesOnCell : int[maxEdges],
    evc : int[3*maxEdges]   --edge pair associated with vertex v and mesh cell i. This is stored as (vertexID, edge1, edge2), and each cell has 10 of those triples arranged sequentially in the array
}

-- A triangluar/dual cell (aka vertex)
fspace D_v {
    vertexID : int,
    lat : double,
    lon : double,
    x : double,
    y : double,
    z : double,
    areaTriangle : double,
    edgesOnVertex : int[vertexDegree],
    cellsOnVertex : int[vertexDegree],
    kiteAreasOnVertex : double[vertexDegree]
}

-- An edge between two vertices that borders two primal cells. (aka edge)
fspace edge {
    edgeID : int,
    lat : double,
    lon : double,
    x : double,
    y : double,
    z : double,
    angleEdge : double,
    nEdgesOnEdge : int,
    dvEdge : double,
    dv1Edge : double,
    dv2Edge : double,
    dcEdge : double,
    cellsOnEdge : int[TWO],
    verticesOnEdge : int[TWO],
    edgesOnEdge_ECP : int[maxEdges2],
    weightsOnEdge : double[maxEdges2]
}



-----------------------------------------------
----- TERRA WRAPPERS FOR NETCDF FUNCTIONS -----
-----------------------------------------------


--Terra function to open the netcdf file and store NCID in the variable passed in.
terra open_file(ncid: &int, file_name: &int8)
	var retval = netcdf.nc_open(file_name, netcdf.NC_NOWRITE, ncid)
    if retval == 1 then 
        cio.printf("Error opening file %s \n", file_name)
    end
end

--Terra function to extract file information (no. of dims, etc).
terra file_inquiry(ncid: int, ndims_in: &int , nvars_in: &int, ngatts_in: &int, unlimdimid_in: &int)
    var retval = netcdf.nc_inq(ncid, ndims_in, nvars_in, ngatts_in, unlimdimid_in)
    if retval == 1 then 
        cio.printf("Error extracting file information of NCID %d \n", ncid)
    end
end

--Terra function to extract dimension ID 
terra get_dimid(ncid: int, name: &int8, dimid: &int)
	var retval = netcdf.nc_inq_dimid(ncid, name, dimid)
    if retval == 1 then 
        cio.printf("Error extracting dimension ID of dimension %s \n", name)
    end
end

--Terra function to extract dimension value 
terra get_dimlength(ncid: int, dimid: int,  dimlength: &uint64)
	var retval = netcdf.nc_inq_dimlen(ncid, dimid, dimlength)
    if retval == 1 then 
        cio.printf("Error extracting dimension length of dimID %d \n", dimid)
    end
end


--Terra function to get the variable ID, given the variable name.
terra get_varid(ncid: int, name: &int8,  varid: &int)
	var retval = netcdf.nc_inq_varid(ncid, name, varid)
    if retval == 1 then 
        cio.printf("Error extracting variable ID of %s\n", name)
    end
end

--Terra function to get the variable values, given the variable ID: For variables with type double.
terra get_var_double(ncid: int, varid: int,  var_array_ptr: &double)
	var retval = netcdf.nc_get_var_double(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error extracting variable values of variable ID %d\n", varid)
    end
end

--Terra function to get the variable values, given the variable ID: For variables with type int.
terra get_var_int(ncid: int, varid: int,  var_array_ptr: &int)
	var retval = netcdf.nc_get_var_int(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error extracting variable values of variable ID %d\n", varid)
    end
end

--Tera function to close file given NCID
terra file_close(ncid: int)
	var retval = netcdf.nc_close(ncid)
    if retval == 1 then 
        cio.printf("Error closing file of NCID %d \n", ncid)
    end
end

--Terra function to close file given NCID
terra file_create(file_name: &int8, ncid_ptr: &int)
	var retval = netcdf.nc_create(file_name, netcdf.NC_CLOBBER, ncid_ptr)
    if retval == 1 then 
        cio.printf("Error creating file of name %s \n", file_name)
    end
end

--Terra function to define a dimension
terra define_dim(ncid: int, dim_name: &int8, dim_size: int, dim_id_ptr: &int)
	var retval = netcdf.nc_def_dim(ncid, dim_name, dim_size, dim_id_ptr)
    if retval == 1 then 
        cio.printf("Error defining dimension of name %s \n", dim_name)
    end
end

--Terra function to define a variable
terra define_var(ncid: int, var_name: &int8, var_type: int, num_dims: int, dim_ids: &int, var_id_ptr: &int)
	var retval = netcdf.nc_def_var(ncid, var_name, var_type, num_dims, dim_ids, var_id_ptr)
    if retval == 1 then 
        cio.printf("Error defining variable of name %s \n", var_name)
    end
end

--Terra function to end metadata reading
terra end_def(ncid: int)
	var retval = netcdf.nc_enddef(ncid)
    if retval == 1 then 
        cio.printf("Error ending def of ncid %d \n", ncid)
    end
end

--Terra function to read variable
terra put_var_double(ncid: int, varid: int, var_array_ptr: &double)
	var retval = netcdf.nc_put_var_double(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error writing variable def of varid %d \n", varid)
    end
end

--Terra function to read variable
terra put_var_int(ncid: int, varid: int, var_array_ptr: &int)
	var retval = netcdf.nc_put_var_int(ncid, varid, var_array_ptr)
    if retval == 1 then 
        cio.printf("Error writing variable def of varid %d \n", varid)
    end
end


task main()

    -------------------------------------------
    ----- READ VARIABLES FROM NETCDF FILE -----
    -------------------------------------------
    cio.printf("Starting to read file... \n")
	var ncid : int

    -- Open the file and store the NCID
	open_file(&ncid, FILE_NAME)

    -- Define the variable IDs
	var latCell_varid : int
	var lonCell_varid : int
    var meshDensity_varid : int
	var xCell_varid : int 
	var yCell_varid : int
	var zCell_varid : int
	var indexToCellID_varid : int
    var latEdge_varid : int
	var lonEdge_varid : int
	var xEdge_varid : int
	var yEdge_varid : int
	var zEdge_varid : int
	var indexToEdgeID_varid : int
    var latVertex_varid : int
	var lonVertex_varid : int
	var xVertex_varid : int
	var yVertex_varid : int
	var zVertex_varid : int
	var indexToVertexID_varid : int
    var cellsOnEdge_varid : int
    var nEdgesOnCell_varid : int
	var nEdgesOnEdge_varid : int
	var edgesOnCell_varid : int
	var edgesOnEdge_varid : int
	var weightsOnEdge_varid : int
    var dvEdge_varid : int
	var dv1Edge_varid : int
	var dv2Edge_varid : int
	var dcEdge_varid : int
	var angleEdge_varid : int
	var areaCell_varid : int
	var areaTriangle_varid : int
    var cellsOnCell_varid : int
	var verticesOnCell_varid : int
	var verticesOnEdge_varid : int
	var edgesOnVertex_varid : int
	var cellsOnVertex_varid : int
	var kiteAreasOnVertex_varid : int

    -- Define the data structures to store the variable values
	var latCell_in : double[nCells]
	var lonCell_in : double[nCells]
	var meshDensity_in : double[nCells]
	var xCell_in : double[nCells]
	var yCell_in : double[nCells]
	var zCell_in : double[nCells]
	var indexToCellID_in : int[nCells]
    var latEdge_in : double[nEdges]
	var lonEdge_in : double[nEdges]
	var xEdge_in : double[nEdges]
	var yEdge_in : double[nEdges]
	var zEdge_in : double[nEdges]
	var indexToEdgeID_in : int[nEdges]
    var latVertex_in : double[nVertices]
	var lonVertex_in : double[nVertices]
	var xVertex_in : double[nVertices]
	var yVertex_in : double[nVertices]
	var zVertex_in : double[nVertices]
	var indexToVertexID_in : int[nVertices]
    var cellsOnEdge_in : int[nEdges][TWO]
    var nEdgesOnCell_in : int[nCells]
	var nEdgesOnEdge_in : int[nEdges]
	--var edgesOnCell_in : int[nCells][maxEdges]
	--var edgesOnEdge_in : int[nEdges][maxEdges2]
	--var weightsOnEdge_in : double[nEdges][maxEdges2]
    var dvEdge_in : double[nEdges]
	var dv1Edge_in : double[nEdges]
	var dv2Edge_in : double[nEdges]
	var dcEdge_in : double[nEdges]
	var angleEdge_in : double[nEdges]
	var areaCell_in : double[nCells]
	var areaTriangle_in : double[nVertices]
    --var cellsOnCell_in : int[nCells][maxEdges]
	--var verticesOnCell_in : int[nCells][maxEdges]
	--var verticesOnEdge_in : int[nEdges][TWO]
	--var edgesOnVertex_in : int[nVertices][vertexDegree]
	--var cellsOnVertex_in : int[nVertices][vertexDegree]
	--var kiteAreasOnVertex_in : double[nVertices][vertexDegree]
    

    -- Get the variable IDs of all the variables
	get_varid(ncid, "latCell", &latCell_varid)	
	get_varid(ncid, "lonCell", &lonCell_varid)
    get_varid(ncid, "meshDensity", &meshDensity_varid)
	get_varid(ncid, "xCell", &xCell_varid) 
	get_varid(ncid, "yCell", &yCell_varid) 
	get_varid(ncid, "zCell", &zCell_varid)
	get_varid(ncid, "indexToCellID", &indexToCellID_varid)
    get_varid(ncid, "latEdge", &latEdge_varid)
	get_varid(ncid, "lonEdge", &lonEdge_varid)
	get_varid(ncid, "xEdge", &xEdge_varid)
	get_varid(ncid, "yEdge", &yEdge_varid)
	get_varid(ncid, "zEdge", &zEdge_varid)
	get_varid(ncid, "indexToEdgeID", &indexToEdgeID_varid)
    get_varid(ncid, "latVertex", &latVertex_varid)
	get_varid(ncid, "lonVertex", &lonVertex_varid)
	get_varid(ncid, "xVertex", &xVertex_varid)
	get_varid(ncid, "yVertex", &yVertex_varid)
	get_varid(ncid, "zVertex", &zVertex_varid)
	get_varid(ncid, "indexToVertexID", &indexToVertexID_varid)
    get_varid(ncid, "cellsOnEdge", &cellsOnEdge_varid)
    get_varid(ncid, "cellsOnEdge", &cellsOnEdge_varid)
	get_varid(ncid, "nEdgesOnCell", &nEdgesOnCell_varid)
	get_varid(ncid, "nEdgesOnEdge", &nEdgesOnEdge_varid)
	get_varid(ncid, "edgesOnCell", &edgesOnCell_varid)
	get_varid(ncid, "edgesOnEdge", &edgesOnEdge_varid)
	get_varid(ncid, "weightsOnEdge", &weightsOnEdge_varid)
    get_varid(ncid, "dvEdge", &dvEdge_varid)
	get_varid(ncid, "dv1Edge", &dv1Edge_varid)
	get_varid(ncid, "dv2Edge", &dv2Edge_varid)
	get_varid(ncid, "dcEdge", &dcEdge_varid)
	get_varid(ncid, "angleEdge", &angleEdge_varid)
	get_varid(ncid, "areaCell", &areaCell_varid)
	get_varid(ncid, "areaTriangle", &areaTriangle_varid)
    get_varid(ncid, "cellsOnCell", &cellsOnCell_varid)
	get_varid(ncid, "verticesOnCell", &verticesOnCell_varid)
	get_varid(ncid, "verticesOnEdge", &verticesOnEdge_varid)
	get_varid(ncid, "edgesOnVertex", &edgesOnVertex_varid)
	get_varid(ncid, "cellsOnVertex", &cellsOnVertex_varid)
	get_varid(ncid, "kiteAreasOnVertex", &kiteAreasOnVertex_varid)
    
    -- Get the variable values, given the variable IDs (To add: error checking)
	get_var_double(ncid, latCell_varid, &latCell_in[0])
	get_var_double(ncid, lonCell_varid, &lonCell_in[0])
    get_var_double(ncid, meshDensity_varid, &meshDensity_in[0])
    get_var_double(ncid, xCell_varid, &xCell_in[0])
    get_var_double(ncid, yCell_varid, &yCell_in[0])
    get_var_double(ncid, zCell_varid, &zCell_in[0])
    get_var_int(ncid, indexToCellID_varid, &indexToCellID_in[0])
    get_var_double(ncid, latEdge_varid, &latEdge_in[0])
    get_var_double(ncid, lonEdge_varid, &lonEdge_in[0])
    get_var_double(ncid, xEdge_varid, &xEdge_in[0])
    get_var_double(ncid, yEdge_varid, &yEdge_in[0])
    get_var_double(ncid, zEdge_varid, &zEdge_in[0])
    get_var_int(ncid, indexToEdgeID_varid, &indexToEdgeID_in[0])
    get_var_double(ncid, latVertex_varid, &latVertex_in[0])
    get_var_double(ncid, lonVertex_varid, &lonVertex_in[0])
    get_var_double(ncid, xVertex_varid, &xVertex_in[0])
    get_var_double(ncid, yVertex_varid, &yVertex_in[0])
    get_var_double(ncid, zVertex_varid, &zVertex_in[0])
    get_var_int(ncid, indexToVertexID_varid, &indexToVertexID_in[0])
    --get_var_int(ncid, cellsOnEdge_varid, &cellsOnEdge_in[0][0])
    get_var_int(ncid, nEdgesOnCell_varid, &nEdgesOnCell_in[0])
    get_var_int(ncid, nEdgesOnEdge_varid, &nEdgesOnEdge_in[0])
    --get_var_int(ncid, edgesOnCell_varid, &edgesOnCell_in[0][0])
    --get_var_int(ncid, edgesOnEdge_varid, &edgesOnEdge_in[0][0])
    --get_var_double(ncid, weightsOnEdge_varid, &weightsOnEdge_in[0][0])
    get_var_double(ncid, dvEdge_varid, &dvEdge_in[0])
    get_var_double(ncid, dv1Edge_varid, &dv1Edge_in[0])
    get_var_double(ncid, dv2Edge_varid, &dv2Edge_in[0])
    get_var_double(ncid, dcEdge_varid, &dcEdge_in[0])
    get_var_double(ncid, angleEdge_varid, &angleEdge_in[0])
    get_var_double(ncid, areaCell_varid, &areaCell_in[0])
    get_var_double(ncid, areaTriangle_varid, &areaTriangle_in[0])
    --get_var_int(ncid, cellsOnCell_varid, &cellsOnCell_in[0][0])
    --get_var_int(ncid, verticesOnCell_varid, &verticesOnCell_in[0][0])
    --get_var_int(ncid, verticesOnEdge_varid, &verticesOnEdge_in[0][0])
    --get_var_int(ncid, edgesOnVertex_varid, &edgesOnVertex_in[0][0])
    --get_var_int(ncid, cellsOnVertex_varid, &cellsOnVertex_in[0][0])
    --get_var_double(ncid, kiteAreasOnVertex_varid, &kiteAreasOnVertex_in[0][0])

    --------------------------------------------
    ----- CONVERT 2D ARRAYS INTO 1D ARRAYS -----
    --------------------------------------------
    --Ugly code because the netcdf function return the 2d arrays incorrectly, so I covert them to 1d arrays for easy access. 
    -- To look into: there is probably a better way of doing this

    --Temporary variables to store the 2d variables in 1d arrays
    var EC_temp : int[nCells*maxEdges]
    var VC_temp : int[nCells*maxEdges]
    var CC_temp : int[nCells*maxEdges]
    var k = 0
    for i = 0, maxEdges do 
	    for j = 0, nCells do
            --EC_temp[k] = edgesOnCell_in[i][j]
            --VC_temp[k] = verticesOnCell_in[i][j]
            --CC_temp[k] = cellsOnCell_in[i][j]
            --cio.printf("edgesOnCell: Edge index %d, Cell Index %d is value:%d\n", i, j, edgesOnCell_in[i][j])
            --cio.printf("edgesOnCell Array index %d is value: %d \n", k, edgesOnCell_in[i][j])
            --cio.printf("verticesOnCell: Vertex index %d, Cell Index %d is value:%d\n", i, j, verticesOnCell_in[i][j])
            --cio.printf("verticesOnCell Array index %d is value: %d \n", k, verticesOnCell_in[i][j])
            --cio.printf("cellsOnCell: OuterCell index %d, InnerCell Index %d is value:%d\n", i, j, cellsOnCell_in[i][j])
            --cio.printf("cellsOnCell Array index %d is value: %d \n", k, cellsOnCell_in[i][j])
            k = k+1
        end
	end

    var EV_temp : int[nVertices*vertexDegree]
    var CV_temp : int[nVertices*vertexDegree]
    var KV_temp : int[nVertices*vertexDegree]
    k = 0
    for i = 0, vertexDegree do 
	    for j = 0, nVertices do
            --EV_temp[k] = edgesOnVertex_in[i][j]
            --CV_temp[k] = cellsOnVertex_in[i][j]
            --KV_temp[k] = kiteAreasOnVertex_in[i][j]
            --cio.printf("cellsOnVertex: Cell index %d, Vertex Index %d is value:%d\n", i, j, cellsOnVertex_in[i][j])
            --cio.printf("cellsOnVertex Array index %d is value: %d \n", k, cellsOnVertex_in[i][j])
            --cio.printf("edgesOnVertex: Edge index %d, Vertex Index %d is value:%d\n", i, j, edgesOnVertex_in[i][j])
            --cio.printf("edgesOnVertex Array index %d is value: %d \n", k, edgesOnVertex_in[i][j])
            --cio.printf("kiteAreasOnVertex: Kite area %d, Vertex Index %d is value: %f\n", i, j, kiteAreasOnVertex_in[i][j])
            --cio.printf("kiteAreasOnVertex Array index %d is value: %f \n", k, kiteAreasOnVertex_in[i][j])
            k = k+1
        end
	end

    var VE_temp : int[nEdges*TWO]
    var CE_temp : int[nEdges*TWO]
    k = 0
    for i = 0, TWO do 
	    for j = 0, nEdges do
            --VE_temp[k] = verticesOnEdge_in[i][j]
            --CE_temp[k] = cellsOnEdge_in[i][j]
            --cio.printf("verticesOnEdge: Vertex index %d, Edge Index %d is value:%d\n", i, j, verticesOnEdge_in[i][j])
            --cio.printf("verticesOnEdge Array index %d is value: %d \n", k, verticesOnEdge_in[i][j])
            --cio.printf("cellsOnEdge: Cell index %d, Edge Index %d is value:%d\n", i, j, cellsOnEdge_in[i][j])
            --cio.printf("cellsOnEdge Array index %d is value: %d \n", k, cellsOnEdge_in[i][j])
            k = k+1
        end
	end

    var EE_temp : int[nEdges*maxEdges2]
    var WE_temp : int[nEdges*maxEdges2] 
    k = 0
    for i = 0, maxEdges2 do 
	    for j = 0, nEdges do
            --EE_temp[k] = edgesOnEdge_in[i][j]
            --WE_temp[k] = weightsOnEdge_in[i][j]
            --cio.printf("edgesOnEdge: OuterEdge index %d, InnerEdge Index %d is value: %d\n", i, j, edgesOnEdge_in[i][j])
            --cio.printf("edgesOnEdge Array index %d is value: %d \n", k, edgesOnEdge_in[i][j])
            --cio.printf("weightsOnEdge: Weight index %d, Edge Index %d is value: %f\n", i, j, weightsOnEdge_in[i][j])
            --cio.printf("weightsOnEdge Array index %d is value: %f \n", k, weightsOnEdge_in[i][j])
            k = k+1
        end
	end

    -------------------------------------------
    ----- DEFINE INDEX SPACES AND REGIONS -----
    -------------------------------------------

    -- Define index spaces for cell IDs, vertex IDs and edge IDs
    var cell_id_space = ispace(int1d, nCells)
    var vertex_id_space = ispace(int1d, nVertices)
    var edge_id_space = ispace(int1d, nEdges)

    -- Define regions
    var edge_region = region(edge_id_space, edge)
    var cell_region = region(cell_id_space, P_i)
    var vertex_region = region(vertex_id_space, D_v)


    ----------------------------------
    ----- COPY DATA INTO REGIONS -----
    ----------------------------------

    -- Copy data into cell region
    for i = 0, nCells do 
        cell_region[i].cellID = indexToCellID_in[i]
        cell_region[i].lat = latCell_in[i]
        cell_region[i].lon = lonCell_in[i]
        cell_region[i].x = xCell_in[i]
        cell_region[i].y = yCell_in[i]
        cell_region[i].z = zCell_in[i]
        cell_region[i].nEdgesOnCell = nEdgesOnCell_in[i]
        cell_region[i].meshDensity = meshDensity_in[i]
        cell_region[i].areaCell = areaCell_in[i]
        
        for j = 0, maxEdges do
            --cell_region[i].edgesOnCell[j] = EC_temp[i*maxEdges + j] --cell_region[i].edgesOnCell is a int[maxEdges]
            --cell_region[i].verticesOnCell[j] = VC_temp[i*maxEdges + j] --cell_region[i].verticesOnCell is a int[maxEdges]
            --cell_region[i].cellsOnCell[j] = CC_temp[i*maxEdges + j] --cell_region[i].cellsOnCell is a int[maxEdges]

            --cio.printf("edgesOnCell : Cell %d, Edge %d: edge index is %d\n", i, j, cell_region[i].edgesOnCell[j])
            --cio.printf("verticesOnCell : Cell %d, Vertex %d: Vertex index is %d\n", i, j, cell_region[i].verticesOnCell[j])
            --cio.printf("cellsOnCell : InnerCell %d, OuterCell %d: Cell index is %d\n", i, j, cell_region[i].cellsOnCell[j])
        end 
        --cio.printf("Cell : Cell %d, ID is %d, Lat is %f, Lon is %f\n", i, cell_region[i].lat, cell_region[i].lon)
    end

    for i = 0, nEdges do
        edge_region[i].edgeID = indexToEdgeID_in[i]
        edge_region[i].lat = latEdge_in[i]
        edge_region[i].lon = lonEdge_in[i]
        edge_region[i].x = xEdge_in[i]
        edge_region[i].y = yEdge_in[i]
        edge_region[i].z = zEdge_in[i]
        edge_region[i].nEdgesOnEdge = nEdgesOnEdge_in[i]
        edge_region[i].dvEdge = dvEdge_in[i]
        edge_region[i].dv1Edge = dv1Edge_in[i]
        edge_region[i].dv2Edge = dv2Edge_in[i]
        edge_region[i].dcEdge = dcEdge_in[i]
        edge_region[i].angleEdge = angleEdge_in[i]


        for j = 0, TWO do
            --edge_region[i].cellsOnEdge[j] = CE_temp[i*TWO + j]
            --edge_region[i].verticesOnEdge[j] = VE_temp[i*TWO + j]
            --cio.printf("cellsOnEdge : Edge %d, Cell %d is %d\n", i, j, edge_region[i].cellsOnEdge[j])
            --cio.printf("VerticesOnEdge : Edge %d: Vertex %d is $d\n", i, j, edge_region[i].verticesOnEdge[j])
        end

        for j = 0, maxEdges2 do
            --cio.printf("InnerEdge %d, OuterEdge %d\n", i, j)
            --edge_region[i].edgesOnEdge_ECP[j] = EE_temp[i*maxEdges2 + j]
            --edge_region[i].weightsOnEdge[j] = WE_temp[i*maxEdges2 + j]
            --cio.printf("edgesOnEdge_ECP : InnerEdge %d, OuterEdge %d is %d\n", i, j, edge_region[i].edgesOnEdge_ECP[j])
            --cio.printf("weightsOnEdge : Edge %d: Weight %d is $f\n", i, j, edge_region[i].weightsOnEdge[j])
        end
        
        --cio.printf("Edge: ID is %d, xEdge is %f, yEdge is %f, zEdge is %f \n", i, edge_region[i].x, edge_region[i].y, edge_region[i].z)
    end

    -- Copy data into vertex region
    for i = 0, nVertices do
        vertex_region[i].vertexID = indexToVertexID_in[i]
        vertex_region[i].lat = latVertex_in[i]
        vertex_region[i].lon = lonVertex_in[i]
        vertex_region[i].x = xVertex_in[i]
        vertex_region[i].y = yVertex_in[i]
        vertex_region[i].z = zVertex_in[i]
        vertex_region[i].areaTriangle = areaTriangle_in[i]

        for j = 0, vertexDegree do
            --vertex_region[i].edgesOnVertex[j] = EV_temp[i*vertexDegree + j]
            --vertex_region[i].cellsOnVertex[j] = CV_temp[i*vertexDegree + j]
            --vertex_region[i].kiteAreasOnVertex[j] = KV_temp[i*vertexDegree + j]

            --cio.printf("edgesOnVertex : Vertex %d, Edge %d: Edge index is %d\n", i, j, vertex_region[i].edgesOnVertex[j])
            --cio.printf("cellsOnVertex : Vertex %d, Cell %d: Cell index is %d\n", i, j, vertex_region[i].cellsOnVertex[j])
            --cio.printf("kiteAreasOnVertex : Vertex %d, Kite %d: Kite Area is %f\n", i, j, vertex_region[i].kiteAreasOnVertex[j])
        end
        
        --cio.printf("Vertex ID is %d, xVertex is %f, yVertex is %f, zVertex is %f \n", i, vertex_region[i].x, vertex_region[i].y, vertex_region[i].z)
    end

    -------------------------
    ----- CALCULATE EVC -----
    -------------------------
    -- I know I should do something more intelligent to get the common elements: but for now we do a brute force search to get EVC
    
    --First, we iterate through the cells and get the edgesOnCell array for each cell
    --for i = 0, nCells do
    --    var curr_edgesOnCell = cell_region[i].edgesOnCell 

    --    --Then we iterate through the vertices of that cell 
    --    for j = 0, maxEdges do
    --        var currVertexID = cell_region[i].verticesOnCell[j]
    --        cell_region[i].evc[j*3] = currVertexID
    --        --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3, cell_region[i].evc[j*3])
    --
    --        if currVertexID == 0 then
    --           cell_region[i].evc[j*3 + 1] = 0
    --            cell_region[i].evc[j*3 + 2] = 0
    --            --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + 1, cell_region[i].evc[j*3 + 1])
    --            --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + 2, cell_region[i].evc[j*3 + 2])
    --
    --        --If there is a vertex, we get the edges on that vertex
    --        elseif currVertexID ~= 0 then 
    --            var curr_edgesOnVertex = vertex_region[currVertexID-1].edgesOnVertex               
    --            var count = 1 
    --
    --            --Then, we get overlapping edges between curr_edgesOnVertex and curr_edgesOnCell to get EVC
    --            for k = 0, vertexDegree do
    --                var currEdgeID = curr_edgesOnVertex[k]
    --                for l = 0, maxEdges do
    --                    if currEdgeID == curr_edgesOnCell[l] and count < 3 then
    --                        cell_region[i].evc[j*3 + count] = currEdgeID
    --                        --io.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + count, cell_region[i].evc[j*3 + count])
    --                        count = count+1
    --                   end
    --                end
    --            end
    --        end
    --    end
    --end

     -- Close the file
	file_close(ncid)
    cio.printf("Successfully read file! \n")

    
    ----------------------------------------------------
    ------- TESTING CODE: WRITING NETCDF OUTPUT --------
    ----------------------------------------------------

    -- We create a netcdf file using the data in the regions, to test whether the data was written correctly.
    cio.printf("Starting to write netcdf file..\n")
    var ncid_copy = 65537

    --Create a netcdf file
    file_create("newfile.nc", &ncid_copy)

    --Initialize the file's dimension variables
    var nCells_dimid_copy : int
    var nEdges_dimid_copy : int
    var nVertices_dimid_copy : int
    var maxEdges_dimid_copy : int
    var maxEdges2_dimid_copy : int
    var TWO_dimid_copy : int
    var vertexDegree_dimid_copy : int
    var nVertLevels_dimid_copy : int
    var time_dimid_copy : int

    --Define the dimension variables
    --define_dim(ncid: int, dim_name: &int, dim_size: int, dim_id_ptr: &int)
    define_dim(ncid_copy, "nCells", nCells, &nCells_dimid_copy)
    define_dim(ncid_copy, "nEdges", nEdges, &nEdges_dimid_copy)
    define_dim(ncid_copy, "nVertices", nVertices, &nVertices_dimid_copy)
    define_dim(ncid_copy, "maxEdges", maxEdges, &maxEdges_dimid_copy)
    define_dim(ncid_copy, "maxEdges2", maxEdges2, &maxEdges2_dimid_copy)
    define_dim(ncid_copy, "TWO", TWO, &TWO_dimid_copy)
    define_dim(ncid_copy, "vertexDegree", vertexDegree, &vertexDegree_dimid_copy)
    define_dim(ncid_copy, "nVertLevels", nVertLevels, &nVertLevels_dimid_copy)
    define_dim(ncid_copy, "Time", netcdf.NC_UNLIMITED, &time_dimid_copy)

    --For the 2D variables, the dimIDs need to be put in arrays
    var nEdges_TWO_dimids = array(nEdges_dimid_copy, TWO_dimid_copy)
    var nCells_maxEdges_dimids = array(nCells_dimid_copy, maxEdges_dimid_copy)
    var nEdges_maxEdges2_dimids = array(nEdges_dimid_copy, maxEdges2_dimid_copy)
    var nVertices_vertexDegree_dimids = array(nVertices_dimid_copy, vertexDegree_dimid_copy)

    --Initialize the variable IDs
    var latCell_varid_copy : int
    var lonCell_varid_copy : int
    var meshDensity_varid_copy : int
	var xCell_varid_copy : int 
	var yCell_varid_copy : int
	var zCell_varid_copy : int
	var indexToCellID_varid_copy : int
    var latEdge_varid_copy : int
	var lonEdge_varid_copy : int
	var xEdge_varid_copy : int
	var yEdge_varid_copy : int
	var zEdge_varid_copy : int
	var indexToEdgeID_varid_copy : int
    var latVertex_varid_copy : int
	var lonVertex_varid_copy : int
	var xVertex_varid_copy : int
	var yVertex_varid_copy : int
	var zVertex_varid_copy : int
	var indexToVertexID_varid_copy : int
    var cellsOnEdge_varid_copy : int
    var nEdgesOnCell_varid_copy : int
	var nEdgesOnEdge_varid_copy : int
	var edgesOnCell_varid_copy : int
	var edgesOnEdge_varid_copy : int
	var weightsOnEdge_varid_copy : int
    var dvEdge_varid_copy : int
	var dv1Edge_varid_copy : int
	var dv2Edge_varid_copy : int
	var dcEdge_varid_copy : int
	var angleEdge_varid_copy : int
	var areaCell_varid_copy : int
	var areaTriangle_varid_copy : int
    var cellsOnCell_varid_copy : int
	var verticesOnCell_varid_copy : int
	var verticesOnEdge_varid_copy : int
	var edgesOnVertex_varid_copy : int
	var cellsOnVertex_varid_copy : int
	var kiteAreasOnVertex_varid_copy : int

    --Define the variable IDs
    --define_var(ncid: int, var_name: &int, var_type: int, num_dims: int, dim_ids: &int, var_id_ptr: &int)
    define_var(ncid_copy, "latCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &latCell_varid_copy)
    define_var(ncid_copy, "lonCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &lonCell_varid_copy)
    define_var(ncid_copy, "meshDensity", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &meshDensity_varid_copy)
    define_var(ncid_copy, "xCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &xCell_varid_copy)
    define_var(ncid_copy, "yCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &yCell_varid_copy)
    define_var(ncid_copy, "zCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &zCell_varid_copy)
    define_var(ncid_copy, "indexToCellID", netcdf.NC_INT, 1, &nCells_dimid_copy, &indexToCellID_varid_copy)
    define_var(ncid_copy, "latEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &latEdge_varid_copy)
    define_var(ncid_copy, "lonEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &lonEdge_varid_copy)
    define_var(ncid_copy, "xEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &xEdge_varid_copy)
    define_var(ncid_copy, "yEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &yEdge_varid_copy)
    define_var(ncid_copy, "zEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &zEdge_varid_copy)
    define_var(ncid_copy, "indexToEdgeID", netcdf.NC_INT, 1, &nEdges_dimid_copy, &indexToEdgeID_varid_copy)
    define_var(ncid_copy, "latVertex", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &latVertex_varid_copy)
    define_var(ncid_copy, "lonVertex", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &lonVertex_varid_copy)
    define_var(ncid_copy, "xVertex", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &xVertex_varid_copy)
    define_var(ncid_copy, "yVertex", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &yVertex_varid_copy)
    define_var(ncid_copy, "zVertex", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &zVertex_varid_copy)
    define_var(ncid_copy, "indexToVertexID", netcdf.NC_INT, 1, &nVertices_dimid_copy, &indexToVertexID_varid_copy)
    define_var(ncid_copy, "cellsOnEdge", netcdf.NC_INT, 2, nEdges_TWO_dimids, &cellsOnEdge_varid_copy)
    define_var(ncid_copy, "nEdgesOnCell", netcdf.NC_INT, 1, &nCells_dimid_copy, &nEdgesOnCell_varid_copy)
    define_var(ncid_copy, "nEdgesOnEdge", netcdf.NC_INT, 1, &nEdges_dimid_copy, &nEdgesOnEdge_varid_copy)
    define_var(ncid_copy, "edgesOnCell", netcdf.NC_INT, 2, nCells_maxEdges_dimids, &edgesOnCell_varid_copy)
    define_var(ncid_copy, "edgesOnEdge", netcdf.NC_INT, 2, nEdges_maxEdges2_dimids, &edgesOnEdge_varid_copy)
    define_var(ncid_copy, "weightsOnEdge", netcdf.NC_DOUBLE, 2, nEdges_maxEdges2_dimids, &weightsOnEdge_varid_copy)
    define_var(ncid_copy, "dvEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &dvEdge_varid_copy)
    define_var(ncid_copy, "dv1Edge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &dv1Edge_varid_copy)
    define_var(ncid_copy, "dv2Edge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &dv2Edge_varid_copy)
    define_var(ncid_copy, "dcEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &dcEdge_varid_copy)
    define_var(ncid_copy, "angleEdge", netcdf.NC_DOUBLE, 1, &nEdges_dimid_copy, &angleEdge_varid_copy)
    define_var(ncid_copy, "areaCell", netcdf.NC_DOUBLE, 1, &nCells_dimid_copy, &areaCell_varid_copy)
    define_var(ncid_copy, "areaTriangle", netcdf.NC_DOUBLE, 1, &nVertices_dimid_copy, &areaTriangle_varid_copy)
    define_var(ncid_copy, "cellsOnCell", netcdf.NC_INT, 2, nCells_maxEdges_dimids, &cellsOnCell_varid_copy)
    define_var(ncid_copy, "verticesOnCell", netcdf.NC_INT, 2, nCells_maxEdges_dimids, &verticesOnCell_varid_copy)
    define_var(ncid_copy, "verticesOnEdge", netcdf.NC_INT, 2, nEdges_TWO_dimids, &verticesOnEdge_varid_copy)
    define_var(ncid_copy, "edgesOnVertex", netcdf.NC_INT, 2, nVertices_vertexDegree_dimids, &edgesOnVertex_varid_copy)
    define_var(ncid_copy, "cellsOnVertex", netcdf.NC_INT, 2, nVertices_vertexDegree_dimids, &cellsOnVertex_varid_copy)
    define_var(ncid_copy, "kiteAreasOnVertex", netcdf.NC_DOUBLE, 2, nVertices_vertexDegree_dimids, &kiteAreasOnVertex_varid_copy)
    
    --This function signals that we're done writing the metadata.
    end_def(ncid_copy)

    --Now define the new arrays to hold the data that will be put in the netcdf files
    var latCell_in_copy : double[nCells]
	var lonCell_in_copy : double[nCells]
	var meshDensity_in_copy : double[nCells]
	var xCell_in_copy : double[nCells]
	var yCell_in_copy : double[nCells]
	var zCell_in_copy : double[nCells]
	var indexToCellID_in_copy : int[nCells]
    var latEdge_in_copy : double[nEdges]
	var lonEdge_in_copy : double[nEdges]
	var xEdge_in_copy : double[nEdges]
	var yEdge_in_copy : double[nEdges]
	var zEdge_in_copy : double[nEdges]
	var indexToEdgeID_in_copy : int[nEdges]
    var latVertex_in_copy : double[nVertices]
	var lonVertex_in_copy : double[nVertices]
	var xVertex_in_copy : double[nVertices]
	var yVertex_in_copy : double[nVertices]
	var zVertex_in_copy : double[nVertices]
	var indexToVertexID_in_copy : int[nVertices]
    --var cellsOnEdge_in_copy : int[nEdges][TWO]
    var nEdgesOnCell_in_copy : int[nCells]
	var nEdgesOnEdge_in_copy : int[nEdges]
	--var edgesOnCell_in_copy : int[nCells][maxEdges]
	--var edgesOnEdge_in_copy : int[nEdges][maxEdges2]
	--var weightsOnEdge_in_copy : double[nEdges][maxEdges2]
    var dvEdge_in_copy : double[nEdges]
	var dv1Edge_in_copy : double[nEdges]
	var dv2Edge_in_copy : double[nEdges]
	var dcEdge_in_copy : double[nEdges]
	var angleEdge_in_copy : double[nEdges]
	var areaCell_in_copy : double[nCells]
	var areaTriangle_in_copy : double[nVertices]
    --var cellsOnCell_in_copy : int[nCells][maxEdges]
	--var verticesOnCell_in_copy : int[nCells][maxEdges]
	--var verticesOnEdge_in_copy : int[nEdges][TWO]
	--var edgesOnVertex_in_copy : int[nVertices][vertexDegree]
	--var cellsOnVertex_in_copy : int[nVertices][vertexDegree]
	--var kiteAreasOnVertex_in_copy : double[nVertices][vertexDegree]

    for i = 0, nCells do 
        --latCell_in_copy[i] = cell_region[i].lat
        --lonCell_in_copy[i] = cell_region[i].lon
        --meshDensity_in_copy[i] = cell_region[i].meshDensity
        --xCell_in_copy[i] = cell_region[i].x
        --yCell_in_copy[i] = cell_region[i].y
        --zCell_in_copy[i] = cell_region[i].z
        --indexToCellID_in_copy[i] = cell_region[i].cellID
        --nEdgesOnCell_in_copy[i] = cell_region[i].nEdgesOnCell
        --areaCell_in_copy[i] = cell_region[i].areaCell
    end

    for i = 0, nEdges do
        --latEdge_in_copy[i] = edge_region[i].lat
        --lonEdge_in_copy[i] = edge_region[i].lon
        --xEdge_in_copy[i] = edge_region[i].x
        --yEdge_in_copy[i] = edge_region[i].y
        --zEdge_in_copy[i] = edge_region[i].z
        --indexToEdgeID_in_copy[i] = edge_region[i].edgeID
        --nEdgesOnEdge_in_copy[i] = edge_region[i].nEdgesOnEdge
        --dvEdge_in_copy[i] = edge_region[i].dvEdge
        --dv1Edge_in_copy[i] = edge_region[i].dv1Edge
        --dv2Edge_in_copy[i] = edge_region[i].dv2Edge
        --dcEdge_in_copy[i] = edge_region[i].dcEdge
        --angleEdge_in_copy[i] = edge_region[i].angleEdge
    end

    for i = 0, nVertices do
        latVertex_in_copy[i] = vertex_region[i].lat
        lonVertex_in_copy[i] = vertex_region[i].lon
        xVertex_in_copy[i] = vertex_region[i].x
        yVertex_in_copy[i] = vertex_region[i].y
        zVertex_in_copy[i] = vertex_region[i].z
        indexToVertexID_in_copy[i] = vertex_region[i].vertexID
        areaTriangle_in_copy[i] = vertex_region[i].areaTriangle
    end
    

    --We put the data into the netcdf file.
    --put_var_double(ncid: int, varid: int, var_array_ptr: &int)
    --put_var_double(ncid_copy, latCell_varid_copy, &latCell_in_copy[0])
    --put_var_double(ncid_copy, lonCell_varid_copy, &lonCell_in_copy[0])
    --put_var_double(ncid_copy, meshDensity_varid_copy, &meshDensity_in_copy[0])
    --put_var_double(ncid_copy, xCell_varid_copy, &xCell_in_copy[0])
    --put_var_double(ncid_copy, yCell_varid_copy, &yCell_in_copy[0])
    --put_var_double(ncid_copy, zCell_varid_copy, &zCell_in_copy[0])
    --put_var_int(ncid_copy, indexToCellID_varid_copy, &indexToCellID_in_copy[0])
    --put_var_int(ncid_copy, nEdgesOnEdge_varid_copy, &nEdgesOnCell_in_copy[0])
    --put_var_double(ncid_copy, areaCell_varid_copy, &areaCell_in_copy[0])

    --put_var_double(ncid_copy, latEdge_varid_copy, &latEdge_in_copy[0])
    --put_var_double(ncid_copy, lonEdge_varid_copy, &lonEdge_in_copy[0])
    --put_var_double(ncid_copy, xEdge_varid_copy, &xEdge_in_copy[0])
    --put_var_double(ncid_copy, yEdge_varid_copy, &yEdge_in_copy[0])
    --put_var_double(ncid_copy, zEdge_varid_copy, &zEdge_in_copy[0])
    --put_var_int(ncid_copy, indexToEdgeID_varid_copy, &indexToEdgeID_in_copy[0])
    --put_var_int(ncid_copy, nEdgesOnEdge_varid_copy, &nEdgesOnEdge_in_copy[0])
    --put_var_double(ncid_copy, dvEdge_varid_copy, &dvEdge_in_copy[0])
    --put_var_double(ncid_copy, dv1Edge_varid_copy, &dv1Edge_in_copy[0])
    --put_var_double(ncid_copy, dv2Edge_varid_copy, &dv2Edge_in_copy[0])
    --put_var_double(ncid_copy, dcEdge_varid_copy, &dcEdge_in_copy[0])
    --put_var_double(ncid_copy, angleEdge_varid_copy, &angleEdge_in_copy[0])

    put_var_double(ncid_copy, latVertex_varid_copy, &latVertex_in_copy[0])
    put_var_double(ncid_copy, lonVertex_varid_copy, &lonVertex_in_copy[0])
    put_var_double(ncid_copy, xVertex_varid_copy, &xVertex_in_copy[0])
    put_var_double(ncid_copy, yVertex_varid_copy, &yVertex_in_copy[0])
    put_var_double(ncid_copy, zVertex_varid_copy, &zVertex_in_copy[0])
    put_var_int(ncid_copy, indexToVertexID_varid_copy, &indexToVertexID_in_copy[0])
    put_var_double(ncid_copy, areaTriangle_varid_copy, &areaTriangle_in_copy[0])

    -- Close the file
	file_close(ncid_copy)
    cio.printf("Successfully written netcdf file!\n")

end
regentlib.start(main)