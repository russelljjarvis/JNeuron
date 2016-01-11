
#=
Main data container for JNeuron
=#

add_sec(neuron::Neuron, sec::Section)=push!(neuron.secstack,sec)

function set_nsegs!(neuron::Neuron,frequency=100.0,d_lambda=.1)

    neuron.internal_nodes=[Array(Int64,0) for i=1:4]
    
    nodesec=zeros(Int64,length(neuron.secstack)+1)
    nseglist=zeros(Int64,length(neuron.secstack))
    nodesec[1]=1
    first=0
    last=0

    #find total number of segments
    for i=1:length(neuron.secstack)
        
        lambda=lambda_f(frequency, neuron.secstack[i], neuron)
        nseg=floor(Int64, (neuron.secstack[i].length / (d_lambda * lambda) + .9) /2 )*2+1

        nodesec[i+1]=nodesec[i]+nseg
        
        nseglist[i]=nseg
                        
    end
    
    for i=1:length(neuron.secstack)

        if neuron.secstack[i].mtype>1

            for j=1:nseglist[i]
           
                (area, ri,mypt3d) = r_a_calc(neuron.secstack[i],j,nseglist[i],neuron.Ra)
                
                if j==1
                    parent=nodesec[neuron.secstack[i].parent+1]+neuron.secstack[i].parent-1
                    if nseglist[i]==1
                        if length(neuron.secstack[i].child)==0
                            children=Array(Int64,0)
                        else
                            children=Int64[nodesec[neuron.secstack[i].child[k]]+neuron.secstack[i].child[k]-1 for k=1:length(neuron.secstack[i].child)]
                        end
                        
                    else
                        children=Int64[length(neuron.nodes)+2]
                    end
                elseif j==nseglist[i]
                    parent=length(neuron.nodes)
                    children=Int64[nodesec[neuron.secstack[i].child[k]]+neuron.secstack[i].child[k]-1 for k=1:length(neuron.secstack[i].child)]
                else
                    parent=length(neuron.nodes)
                    children=Int64[length(neuron.nodes)+2]
                end

                if (j==1)&&(j==nseglist[i])

                    first=length(neuron.nodes)+1
                    last=length(neuron.nodes)+2

                    #create regular node
                    internal_node(neuron,area,ri,parent,[length(neuron.nodes)+2],mypt3d,i)

                    #create internode at end of section
                    edge_node(neuron,length(neuron.nodes),children,mypt3d[end])
                
                elseif j==1

                    first=length(neuron.nodes)+1

                    #create regular node
                    internal_node(neuron,area,ri,parent,children,mypt3d,i)
                            
                elseif j==nseglist[i]

                    last=length(neuron.nodes)+2
                
                    #create regular node
                    internal_node(neuron,area,ri,parent,[length(neuron.nodes)+2],mypt3d,i)
                    
                    #create internode at end of section
                    edge_node(neuron,length(neuron.nodes),children,mypt3d[end])

                else
                
                    internal_node(neuron,area,ri,parent,children,mypt3d,i)

                end

            end

        else

            first=length(neuron.nodes)+1
            last=length(neuron.nodes)+3
            #approximate soma as 1 segments with everything connected at middle
            
            for j=1:3

                if j ==1 
                    parent=length(neuron.nodes)+2
                    children=Array(Int64,0)

                    edge_node(neuron,parent,children,length(neuron.secstack[end].pt3d))
                    
                elseif j == 2

                    parent=0
                    children=Int64[nodesec[neuron.secstack[i].child[k]]+neuron.secstack[i].child[k]-1 for k=1:length(neuron.secstack[i].child)]
                    
                    (area, ri, mypt3d) = r_a_calc(neuron.secstack[i],1,1,neuron.Ra)
                    push!(children,length(neuron.nodes))
                    push!(children,length(neuron.nodes)+2)

                    internal_node(neuron,area,ri,parent,children,mypt3d,i)
                    
                else
                    parent=length(neuron.nodes)
                    children=Array(Int64,0)

                    edge_node(neuron,parent,children,1)
                    
                end
                
            end
                  
        end
        
        #map pnode of this section to newly created nodes            
        Section!(neuron,i,first:last)
               
    end

    nothing
      
end

function lambda_f(frequency::Float64,sec::Section,neuron::Neuron)
    
    x1 = 0.0
    d1 = sec.pt3d[1].d
    lam = 0.0

    for i=2:length(sec.pt3d)
        x2=sec.pt3d[i].arc*sec.length
        d2=sec.pt3d[i].d
        lam+= (x2-x1)/sqrt(d1+d2)
        x1=x2
        d1=d2
    end

    lam *= sqrt(2) * 1e-5 * sqrt(4*pi*frequency*neuron.Ra*neuron.Cm)

    sec.length/lam
    
end

function internal_node(neuron::Neuron,area,ri,parent,children,mypt3d,i)
    push!(neuron.nodes,Node(area,ri,parent,children,true,mypt3d,Prop0))

    push!(neuron.internal_nodes[neuron.secstack[i].mtype],length(neuron.nodes))
end

function edge_node(neuron::Neuron,parent,children,mypt3d)
    push!(neuron.nodes,Node(SegArea(50.0,50.0,100.0),SegRi(0.0,0.0),parent,children,false,mypt3d:mypt3d,Prop0))
end

function find_parents!(neuron::Neuron)
    for i=1:length(neuron.secstack)
        for j=1:length(neuron.secstack[i].child)
            Section!(neuron,neuron.secstack[i].child[j],i)
        end                
    end

    nothing
end

function Section!(neuron::Neuron,ind::Int64,i::Int64)
    sec=neuron.secstack[ind]
    neuron.secstack[ind]=Section(sec.mtype,sec.pnode,sec.child,i,sec.pt3d,sec.length)
    nothing
end

function Section!(neuron::Neuron,ind::Int64,i::UnitRange{Int64})
    sec=neuron.secstack[ind]
    neuron.secstack[ind]=Section(sec.mtype,i,sec.child,sec.parent,sec.pt3d,sec.length)
    nothing
end
