import "regent"

require "data_structures"
require "netcdf_tasks"
require "dynamics_tasks"
require "rk_timestep"

local c = regentlib.c
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
local GRAPH_FILE_NAME = "x1.2562.graph.info.part.16"
local MAXCHAR = 5
local NUM_PARTITIONS = 16


--Terra function to read the cell partitions from graph.info file. Returns an array where each element is the partition number of that cell index.
terra read_file(file_name: &int8) : int[nCells]
    var file = c.fopen(file_name, "r")
    regentlib.assert(file ~= nil, "failed to open graph.info file")
    var str : int8[MAXCHAR]
    var partition_array : int[nCells]
    var i = 0
    while c.fgets(str, MAXCHAR, file) ~= nil do
        partition_array[i] = c.atoi(str)
        i = i+1
    end
    return partition_array
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

    -- Define and malloc the data structures to store the variable values
    var latCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var lonCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var meshDensity_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var xCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var yCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var zCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var indexToCellID_in : &int = [&int](c.malloc([sizeof(int)] * nCells))
    var latEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var lonEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var xEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var yEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var zEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var indexToEdgeID_in : &int = [&int](c.malloc([sizeof(int)] * nEdges))
    var latVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var lonVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var xVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var yVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var zVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var indexToVertexID_in : &int = [&int](c.malloc([sizeof(int)] * nVertices))
    var cellsOnEdge_in : &int = [&int](c.malloc([sizeof(int)] * nEdges*TWO))
    var nEdgesOnCell_in : &int = [&int](c.malloc([sizeof(int)] * nCells))
    var nEdgesOnEdge_in : &int = [&int](c.malloc([sizeof(int)] * nEdges))
    var edgesOnCell_in : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var edgesOnEdge_in : &int = [&int](c.malloc([sizeof(int)] * nEdges*maxEdges2))
    var weightsOnEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges*maxEdges2))
    var dvEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dv1Edge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dv2Edge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dcEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var angleEdge_in : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var areaCell_in : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var areaTriangle_in : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var cellsOnCell_in : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var verticesOnCell_in : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var verticesOnEdge_in : &int = [&int](c.malloc([sizeof(int)] * nEdges*TWO))
    var edgesOnVertex_in : &int = [&int](c.malloc([sizeof(int)] * nVertices*vertexDegree))
    var cellsOnVertex_in : &int = [&int](c.malloc([sizeof(int)] * nVertices*vertexDegree))
    var kiteAreasOnVertex_in : &double = [&double](c.malloc([sizeof(double)] * nVertices*vertexDegree))


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

    -- Get the variable values, given the variable IDs
    get_var_double(ncid, latCell_varid, latCell_in)
    get_var_double(ncid, lonCell_varid, lonCell_in)
    get_var_double(ncid, meshDensity_varid, meshDensity_in)
    get_var_double(ncid, xCell_varid, xCell_in)
    get_var_double(ncid, yCell_varid, yCell_in)
    get_var_double(ncid, zCell_varid, zCell_in)
    get_var_int(ncid, indexToCellID_varid, indexToCellID_in)
    get_var_double(ncid, latEdge_varid, latEdge_in)
    get_var_double(ncid, lonEdge_varid, lonEdge_in)
    get_var_double(ncid, xEdge_varid, xEdge_in)
    get_var_double(ncid, yEdge_varid, yEdge_in)
    get_var_double(ncid, zEdge_varid, zEdge_in)
    get_var_int(ncid, indexToEdgeID_varid, indexToEdgeID_in)
    get_var_double(ncid, latVertex_varid, latVertex_in)
    get_var_double(ncid, lonVertex_varid, lonVertex_in)
    get_var_double(ncid, xVertex_varid, xVertex_in)
    get_var_double(ncid, yVertex_varid, yVertex_in)
    get_var_double(ncid, zVertex_varid, zVertex_in)
    get_var_int(ncid, indexToVertexID_varid, indexToVertexID_in)
    get_var_int(ncid, cellsOnEdge_varid, cellsOnEdge_in)
    get_var_int(ncid, nEdgesOnCell_varid, nEdgesOnCell_in)
    get_var_int(ncid, nEdgesOnEdge_varid, nEdgesOnEdge_in)
    get_var_int(ncid, edgesOnCell_varid, edgesOnCell_in)
    get_var_int(ncid, edgesOnEdge_varid, edgesOnEdge_in)
    get_var_double(ncid, weightsOnEdge_varid, weightsOnEdge_in)
    get_var_double(ncid, dvEdge_varid, dvEdge_in)
    get_var_double(ncid, dv1Edge_varid, dv1Edge_in)
    get_var_double(ncid, dv2Edge_varid, dv2Edge_in)
    get_var_double(ncid, dcEdge_varid, dcEdge_in)
    get_var_double(ncid, angleEdge_varid, angleEdge_in)
    get_var_double(ncid, areaCell_varid, areaCell_in)
    get_var_double(ncid, areaTriangle_varid, areaTriangle_in)
    get_var_int(ncid, cellsOnCell_varid, cellsOnCell_in)
    get_var_int(ncid, verticesOnCell_varid, verticesOnCell_in)
    get_var_int(ncid, verticesOnEdge_varid, verticesOnEdge_in)
    get_var_int(ncid, edgesOnVertex_varid, edgesOnVertex_in)
    get_var_int(ncid, cellsOnVertex_varid, cellsOnVertex_in)
    get_var_double(ncid, kiteAreasOnVertex_varid, kiteAreasOnVertex_in)

    -------------------------------------------
    ----- DEFINE INDEX SPACES AND REGIONS -----
    -------------------------------------------

    -- Define index spaces for cell IDs, vertex IDs and edge IDs
    var cell_id_space = ispace(int1d, nCells)
    var vertex_id_space = ispace(int1d, nVertices)
    var edge_id_space = ispace(int1d, nEdges)

    -- Define regions
    var edge_region = region(edge_id_space, edge_fs)
    var cell_region = region(cell_id_space, cell_fs)
    var vertex_region = region(vertex_id_space, vertex_fs)

    var partition_array = read_file(GRAPH_FILE_NAME)

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
        cell_region[i].meshDensity = meshDensity_in[i]
        cell_region[i].nEdgesOnCell = nEdgesOnCell_in[i]
        cell_region[i].areaCell = areaCell_in[i]
        cell_region[i].partitionNumber = partition_array[i]

        --cio.printf("Cell : Cell ID %d, partitionNumber %d\n", cell_region[i].cellID, cell_region[i].partitionNumber)

        for j = 0, maxEdges do
            cell_region[i].edgesOnCell[j] = edgesOnCell_in[i*maxEdges + j] --cell_region[i].edgesOnCell is a int[maxEdges]
            cell_region[i].verticesOnCell[j] = verticesOnCell_in[i*maxEdges + j] --cell_region[i].verticesOnCell is a int[maxEdges]
            cell_region[i].cellsOnCell[j] = cellsOnCell_in[i*maxEdges + j] --cell_region[i].cellsOnCell is a int[maxEdges]
            --cio.printf("edgesOnCell : Cell %d, Edge %d: edge index is %d\n", i, j, cell_region[i].edgesOnCell[j])
            --cio.printf("verticesOnCell : Cell %d, Vertex %d: Vertex index is %d\n", i, j, cell_region[i].verticesOnCell[j])
            --cio.printf("cellsOnCell : InnerCell %d, OuterCell %d: Cell index is %d\n", i, j, cell_region[i].cellsOnCell[j])
        end
        --cio.printf("Cell : Cell ID %d, nEdgesOnCell is %d\n", cell_region[i].cellID, cell_region[i].nEdgesOnCell)
    end

    -- Copy data into edge region
    for i = 0, nEdges do
        edge_region[i].edgeID = indexToEdgeID_in[i]
        edge_region[i].lat = latEdge_in[i]
        edge_region[i].lon = lonEdge_in[i]
        edge_region[i].x = xEdge_in[i]
        edge_region[i].y = yEdge_in[i]
        edge_region[i].z = zEdge_in[i]
        edge_region[i].nEdgesOnEdge = nEdgesOnEdge_in[i]
        edge_region[i].angleEdge = angleEdge_in[i]
        edge_region[i].dvEdge = dvEdge_in[i]
        edge_region[i].dv1Edge = dv1Edge_in[i]
        edge_region[i].dv2Edge = dv2Edge_in[i]
        edge_region[i].dcEdge = dcEdge_in[i]


        for j = 0, TWO do
            edge_region[i].cellsOnEdge[j] = cellsOnEdge_in[i*TWO + j]
            edge_region[i].verticesOnEdge[j] = verticesOnEdge_in[i*TWO + j]
            --cio.printf("cellsOnEdge : Edge %d, Cell %d is %d\n", i, j, edge_region[i].cellsOnEdge[j])
            --cio.printf("VerticesOnEdge : Edge %d: Vertex %d is $d\n", i, j, edge_region[i].verticesOnEdge[j])
        end

        for j = 0, maxEdges2 do
            edge_region[i].edgesOnEdge_ECP[j] = edgesOnEdge_in[i*maxEdges2 + j]
            edge_region[i].weightsOnEdge[j] = weightsOnEdge_in[i*maxEdges2 + j]
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
            vertex_region[i].edgesOnVertex[j] = edgesOnVertex_in[i*vertexDegree + j]
            vertex_region[i].cellsOnVertex[j] = cellsOnVertex_in[i*vertexDegree + j]
            vertex_region[i].kiteAreasOnVertex[j] = kiteAreasOnVertex_in[i*vertexDegree + j]

            --cio.printf("edgesOnVertex : Vertex %d, Edge %d: Edge index is %d\n", i, j, vertex_region[i].edgesOnVertex[j])
            --cio.printf("cellsOnVertex : Vertex %d, Cell %d: Cell index is %d\n", i, j, vertex_region[i].cellsOnVertex[j])
            --cio.printf("kiteAreasOnVertex : Vertex %d, Kite %d: Kite Area is %f\n", i, j, vertex_region[i].kiteAreasOnVertex[j])
        end
        --cio.printf("Vertex ID is %d, xVertex is %f, yVertex is %f, zVertex is %f \n", i, vertex_region[i].x, vertex_region[i].y, vertex_region[i].z)
    end

    -------------------------
    ----- CALCULATE EVC -----
    -------------------------
    --I know I should do something more intelligent to get the common elements: but for now we do a brute force search to get EVC

    --First, we iterate through the cells and get the edgesOnCell array for each cell
    for i = 0, nCells do
        var curr_edgesOnCell = cell_region[i].edgesOnCell

    --Then we iterate through the vertices of that cell
        for j = 0, maxEdges do
            var currVertexID = cell_region[i].verticesOnCell[j]
            cell_region[i].evc[j*3] = currVertexID
            --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3, cell_region[i].evc[j*3])

            if currVertexID == 0 then
                cell_region[i].evc[j*3 + 1] = 0
                cell_region[i].evc[j*3 + 2] = 0
                --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + 1, cell_region[i].evc[j*3 + 1])
                --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + 2, cell_region[i].evc[j*3 + 2])

            --If there is a vertex, we get the edges on that vertex
            elseif currVertexID ~= 0 then
                var curr_edgesOnVertex = vertex_region[currVertexID-1].edgesOnVertex
                var count = 1

                --Then, we get overlapping edges between curr_edgesOnVertex and curr_edgesOnCell to get EVC
                for k = 0, vertexDegree do
                    var currEdgeID = curr_edgesOnVertex[k]
                    for l = 0, maxEdges do
                        if currEdgeID == curr_edgesOnCell[l] and count < 3 then
                            cell_region[i].evc[j*3 + count] = currEdgeID
                            --cio.printf("cell_region[%d].evc[%d] = %d\n", i, j*3 + count, cell_region[i].evc[j*3 + count])
                            count = count+1
                        end
                    end
                end
            end
        end
    end

     -- Close the file
	  file_close(ncid)

    -- Free allocated arrays
    c.free(latCell_in)
    c.free(lonCell_in)
    c.free(meshDensity_in)
    c.free(xCell_in)
    c.free(yCell_in)
    c.free(zCell_in)
    c.free(indexToCellID_in)
    c.free(latEdge_in)
    c.free(lonEdge_in)
    c.free(xEdge_in)
    c.free(yEdge_in)
    c.free(zEdge_in)
    c.free(indexToEdgeID_in)
    c.free(latVertex_in)
    c.free(lonVertex_in)
    c.free(xVertex_in)
    c.free(yVertex_in)
    c.free(zVertex_in)
    c.free(indexToVertexID_in)
    c.free(cellsOnEdge_in)
    c.free(nEdgesOnCell_in)
    c.free(nEdgesOnEdge_in)
    c.free(edgesOnCell_in)
    c.free(edgesOnEdge_in)
    c.free(weightsOnEdge_in)
    c.free(dvEdge_in)
    c.free(dv1Edge_in)
    c.free(dv2Edge_in)
    c.free(dcEdge_in)
    c.free(angleEdge_in)
    c.free(areaCell_in)
    c.free(areaTriangle_in)
    c.free(cellsOnCell_in)
    c.free(verticesOnCell_in)
    c.free(verticesOnEdge_in)
    c.free(edgesOnVertex_in)
    c.free(cellsOnVertex_in)
    c.free(kiteAreasOnVertex_in)

    cio.printf("Successfully read file! \n")

    ------------------------------------
    ------- PARTITIONING REGION --------
    ------------------------------------

    var partition_is = ispace(int1d, NUM_PARTITIONS)
    var cell_partition = partition(complete, cell_region.partitionNumber, partition_is)

    --Test code by printing out partitions
    --var i = 0
    --for p in partition_is do
    --    var sub_region = cell_partition[p]
    --    cio.printf("Sub region %d\n", i)
    --    for cell in sub_region do
    --        cio.printf("partitionNumber is %d\n", cell.partitionNumber)
    --    end
    --    i=i+1
    --end

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
    var latCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var lonCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var meshDensity_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var xCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var yCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var zCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var indexToCellID_in_copy : &int = [&int](c.malloc([sizeof(int)] * nCells))
    var latEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var lonEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var xEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var yEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var zEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var indexToEdgeID_in_copy : &int = [&int](c.malloc([sizeof(int)] * nEdges))
    var latVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var lonVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var xVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var yVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var zVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var indexToVertexID_in_copy : &int = [&int](c.malloc([sizeof(int)] * nVertices))
    var cellsOnEdge_in_copy : &int = [&int](c.malloc([sizeof(int)] * nEdges*TWO))
    var nEdgesOnCell_in_copy : &int = [&int](c.malloc([sizeof(int)] * nCells))
    var nEdgesOnEdge_in_copy : &int = [&int](c.malloc([sizeof(int)] * nEdges))
    var edgesOnCell_in_copy : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var edgesOnEdge_in_copy : &int = [&int](c.malloc([sizeof(int)] * nEdges*maxEdges2))
    var weightsOnEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges*maxEdges2))
    var dvEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dv1Edge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dv2Edge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var dcEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var angleEdge_in_copy : &double = [&double](c.malloc([sizeof(double)] * nEdges))
    var areaCell_in_copy : &double = [&double](c.malloc([sizeof(double)] * nCells))
    var areaTriangle_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices))
    var cellsOnCell_in_copy : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var verticesOnCell_in_copy : &int = [&int](c.malloc([sizeof(int)] * nCells*maxEdges))
    var verticesOnEdge_in_copy : &int = [&int](c.malloc([sizeof(int)] * nEdges*TWO))
    var edgesOnVertex_in_copy : &int = [&int](c.malloc([sizeof(int)] * nVertices*vertexDegree))
    var cellsOnVertex_in_copy : &int = [&int](c.malloc([sizeof(int)] * nVertices*vertexDegree))
    var kiteAreasOnVertex_in_copy : &double = [&double](c.malloc([sizeof(double)] * nVertices*vertexDegree))

    --Now we copy the data into the arrays so they can be read into the netcdf files
    for i = 0, nCells do
        latCell_in_copy[i] = cell_region[i].lat
        lonCell_in_copy[i] = cell_region[i].lon
        xCell_in_copy[i] = cell_region[i].x
        yCell_in_copy[i] = cell_region[i].y
        zCell_in_copy[i] = cell_region[i].z
        indexToCellID_in_copy[i] = cell_region[i].cellID
        meshDensity_in_copy[i] = cell_region[i].meshDensity
        nEdgesOnCell_in_copy[i] = cell_region[i].nEdgesOnCell
        areaCell_in_copy[i] = cell_region[i].areaCell

        for j = 0, maxEdges do
            edgesOnCell_in_copy[i*maxEdges + j] = cell_region[i].edgesOnCell[j]
            verticesOnCell_in_copy[i*maxEdges + j] = cell_region[i].verticesOnCell[j]
            cellsOnCell_in_copy[i*maxEdges + j] = cell_region[i].cellsOnCell[j]
        end
        --cio.printf("Cell COPY : Cell ID %d, nEdgesOnCell is %d\n", indexToCellID_in_copy[i], nEdgesOnCell_in_copy[i])
    end

    for i = 0, nEdges do
        latEdge_in_copy[i] = edge_region[i].lat
        lonEdge_in_copy[i] = edge_region[i].lon
        xEdge_in_copy[i] = edge_region[i].x
        yEdge_in_copy[i] = edge_region[i].y
        zEdge_in_copy[i] = edge_region[i].z
        indexToEdgeID_in_copy[i] = edge_region[i].edgeID
        nEdgesOnEdge_in_copy[i] = edge_region[i].nEdgesOnEdge
        dvEdge_in_copy[i] = edge_region[i].dvEdge
        dv1Edge_in_copy[i] = edge_region[i].dv1Edge
        dv2Edge_in_copy[i] = edge_region[i].dv2Edge
        dcEdge_in_copy[i] = edge_region[i].dcEdge
        angleEdge_in_copy[i] = edge_region[i].angleEdge

        for j = 0, TWO do
            cellsOnEdge_in_copy[i*TWO + j] = edge_region[i].cellsOnEdge[j]
            verticesOnEdge_in_copy[i*TWO + j] = edge_region[i].verticesOnEdge[j]
        end

        for j = 0, maxEdges2 do
            edgesOnEdge_in_copy[i*maxEdges2 + j] = edge_region[i].edgesOnEdge_ECP[j]
            weightsOnEdge_in_copy[i*maxEdges2 + j] = edge_region[i].weightsOnEdge[j]
        end
    end

    for i = 0, nVertices do
        latVertex_in_copy[i] = vertex_region[i].lat
        lonVertex_in_copy[i] = vertex_region[i].lon
        xVertex_in_copy[i] = vertex_region[i].x
        yVertex_in_copy[i] = vertex_region[i].y
        zVertex_in_copy[i] = vertex_region[i].z
        indexToVertexID_in_copy[i] = vertex_region[i].vertexID
        areaTriangle_in_copy[i] = vertex_region[i].areaTriangle

        for j = 0, vertexDegree do
            edgesOnVertex_in_copy[i*vertexDegree + j] = vertex_region[i].edgesOnVertex[j]
            cellsOnVertex_in_copy[i*vertexDegree + j] = vertex_region[i].cellsOnVertex[j]
            kiteAreasOnVertex_in_copy[i*vertexDegree + j] = vertex_region[i].kiteAreasOnVertex[j]
        end
    end


    --Now we put the data into the netcdf file.
    put_var_double(ncid_copy, latCell_varid_copy, latCell_in_copy)
    put_var_double(ncid_copy, lonCell_varid_copy, lonCell_in_copy)
    put_var_double(ncid_copy, meshDensity_varid_copy, meshDensity_in_copy)
    put_var_double(ncid_copy, xCell_varid_copy, xCell_in_copy)
    put_var_double(ncid_copy, yCell_varid_copy, yCell_in_copy)
    put_var_double(ncid_copy, zCell_varid_copy, zCell_in_copy)
    put_var_int(ncid_copy, indexToCellID_varid_copy, indexToCellID_in_copy)
    put_var_int(ncid_copy, nEdgesOnCell_varid_copy, nEdgesOnCell_in_copy)
    put_var_double(ncid_copy, areaCell_varid_copy, areaCell_in_copy)
    put_var_int(ncid_copy, edgesOnCell_varid_copy, edgesOnCell_in_copy)
    put_var_int(ncid_copy, verticesOnCell_varid_copy, verticesOnCell_in_copy)
    put_var_int(ncid_copy, cellsOnCell_varid_copy, cellsOnCell_in_copy)

    put_var_double(ncid_copy, latEdge_varid_copy, latEdge_in_copy)
    put_var_double(ncid_copy, lonEdge_varid_copy, lonEdge_in_copy)
    put_var_double(ncid_copy, xEdge_varid_copy, xEdge_in_copy)
    put_var_double(ncid_copy, yEdge_varid_copy, yEdge_in_copy)
    put_var_double(ncid_copy, zEdge_varid_copy, zEdge_in_copy)
    put_var_int(ncid_copy, indexToEdgeID_varid_copy, indexToEdgeID_in_copy)
    put_var_int(ncid_copy, nEdgesOnEdge_varid_copy, nEdgesOnEdge_in_copy)
    put_var_double(ncid_copy, dvEdge_varid_copy, dvEdge_in_copy)
    put_var_double(ncid_copy, dv1Edge_varid_copy, dv1Edge_in_copy)
    put_var_double(ncid_copy, dv2Edge_varid_copy, dv2Edge_in_copy)
    put_var_double(ncid_copy, dcEdge_varid_copy, dcEdge_in_copy)
    put_var_double(ncid_copy, angleEdge_varid_copy, angleEdge_in_copy)
    put_var_int(ncid_copy, cellsOnEdge_varid_copy, cellsOnEdge_in_copy)
    put_var_int(ncid_copy, verticesOnEdge_varid_copy, verticesOnEdge_in_copy)
    put_var_int(ncid_copy, edgesOnEdge_varid_copy, edgesOnEdge_in_copy)
    put_var_double(ncid_copy, weightsOnEdge_varid_copy, weightsOnEdge_in_copy)

    put_var_double(ncid_copy, latVertex_varid_copy, latVertex_in_copy)
    put_var_double(ncid_copy, lonVertex_varid_copy, lonVertex_in_copy)
    put_var_double(ncid_copy, xVertex_varid_copy, xVertex_in_copy)
    put_var_double(ncid_copy, yVertex_varid_copy, yVertex_in_copy)
    put_var_double(ncid_copy, zVertex_varid_copy, zVertex_in_copy)
    put_var_int(ncid_copy, indexToVertexID_varid_copy, indexToVertexID_in_copy)
    put_var_double(ncid_copy, areaTriangle_varid_copy, areaTriangle_in_copy)
    put_var_int(ncid_copy, edgesOnVertex_varid_copy, edgesOnVertex_in_copy)
    put_var_int(ncid_copy, cellsOnVertex_varid_copy, cellsOnVertex_in_copy)
    put_var_double(ncid_copy, kiteAreasOnVertex_varid_copy, kiteAreasOnVertex_in_copy)

    -- Lastly, we free the allocated memory for the 'copy' arrays
    c.free(latCell_in_copy)
    c.free(lonCell_in_copy)
    c.free(meshDensity_in_copy)
    c.free(xCell_in_copy)
    c.free(yCell_in_copy)
    c.free(zCell_in_copy)
    c.free(indexToCellID_in_copy)
    c.free(latEdge_in_copy)
    c.free(lonEdge_in_copy)
    c.free(xEdge_in_copy)
    c.free(yEdge_in_copy)
    c.free(zEdge_in_copy)
    c.free(indexToEdgeID_in_copy)
    c.free(latVertex_in_copy)
    c.free(lonVertex_in_copy)
    c.free(xVertex_in_copy)
    c.free(yVertex_in_copy)
    c.free(zVertex_in_copy)
    c.free(indexToVertexID_in_copy)
    c.free(cellsOnEdge_in_copy)
    c.free(nEdgesOnCell_in_copy)
    c.free(nEdgesOnEdge_in_copy)
    c.free(edgesOnCell_in_copy)
    c.free(edgesOnEdge_in_copy)
    c.free(weightsOnEdge_in_copy)
    c.free(dvEdge_in_copy)
    c.free(dv1Edge_in_copy)
    c.free(dv2Edge_in_copy)
    c.free(dcEdge_in_copy)
    c.free(angleEdge_in_copy)
    c.free(areaCell_in_copy)
    c.free(areaTriangle_in_copy)
    c.free(cellsOnCell_in_copy)
    c.free(verticesOnCell_in_copy)
    c.free(verticesOnEdge_in_copy)
    c.free(edgesOnVertex_in_copy)
    c.free(cellsOnVertex_in_copy)
    c.free(kiteAreasOnVertex_in_copy)

    -- Close the file
    file_close(ncid_copy)
    cio.printf("Successfully written netcdf file!\n")


    --test timestep compile with regions
    --atm_timestep(20.0, vertex_region, edge_region, cell_region)


end
regentlib.start(main)
