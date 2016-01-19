

function add!(n::NetworkS,extra::Extracellular)

    extra.v=zeros(Float64,length(n.t))
    coeffs=Array(Extra_coeffs,0)
    
    for j=1:length(fieldnames(n.neur)),k in getfield(n.neur,j)
        mycoeffs=extracellular(extra,k,0.3)
        push!(coeffs,mycoeffs)
    end
    
    e=typeof(extra)(extra.xyz,coeffs,extra.v)
    push!(n.extra,e)
end

function add!(network::NetworkS,stim::Stim)

    myis=zeros(Float64,length(network.t))

    startind=findfirst(network.t.>stim.tstart)
    endind=findfirst(network.t.>stim.tstop)

    myis[startind:endind]=stim.Is[1]

    stim.Is=myis

    push!(network.stim,stim)   
end

add!(n::NetworkS,intra::Intracellular)=(intra.v=zeros(Float64,length(n.t));push!(n.intra,intra))

function add!(n::NetworkP,extra::Extracellular)

    extra.v=zeros(Float64,length(n.t))
    coeffs=Array(Extra_coeffs,0)
    
    for j=1:length(fieldnames(n.neur))-4
        mycoeffs=add_extra(getfield(n.neur,j),extra)
        append!(coeffs,mycoeffs)
    end
    
    e=typeof(extra)(extra.xyz,coeffs,extra.v)
    push!(n.extra,e)
end

function add!(n::NetworkP,intra::Intracellular)
    intra.v=zeros(Float64,length(n.t))
    push!(n.intra,intra)
    (ind,newx)=neuron_ind(intra.neur,n.neur.c[intra.mtype])
    l=add_intra(ind,newx,intra.node,length(n.t),getfield(n.neur,intra.mtype))
    push!(n.neur.i,l)
    nothing
end

function add!(n::NetworkP,stim::Stim)
    
    myis=zeros(Float64,length(n.t))

    startind=findfirst(n.t.>stim.tstart)
    endind=findfirst(n.t.>stim.tstop)

    myis[startind:endind]=stim.Is[1]

    stim.Is=myis

    push!(n.stim,stim)

    (ind,newx)=neuron_ind(stim.neur,n.neur.c[stim.mtype])
    l=add_stim(ind,newx,stim.node,stim.Is,getfield(n.neur,stim.mtype))
    push!(n.neur.s,l)
end

function run!(n::NetworkS,init=false)

    #get initial conditions if uninitialized
    if init==true
        init!(n)
    end
                         
    for i=1:length(n.t)

        for j=1:length(n.stim)
            @inbounds getfield(n.neur,n.stim[j].mtype)[n.stim[j].neur].rhs[n.stim[j].node]+=n.stim[j].Is[i]
        end

        if n.helper.flags[1]
            count=1
            for j=1 : length(fieldnames(n.neur))
                for k=1:length(getfield(n.neur,j))
                    @inbounds main(getfield(n.neur,j)[k])
                    for l=1:length(n.extra)
                        @inbounds n.extra[l].v[i]+=a_mult_b(n.extra[l].coeffs[count],getfield(n.neur,j)[k])
                    end
                    count+=1
                end
            end
        else
            @inbounds main(n.neur)
        end

        for j=1:length(n.intra)
            @inbounds n.intra[j].v[i]=getfield(n.neur,n.intra[j].mtype)[n.intra[j].neur].v[n.intra[j].node]
        end             
    end

    nothing       
end

function run!(n::NetworkP,init=false)

    #get initial conditions if uninitialized
    if init==true
        init!(n)
    end
                         
    for i=1:length(n.t)
        @inbounds main(n.neur,i)             
    end

    for j=1:length(n.extra)
        for k=1:length(fieldnames(n.neur))-4
            for l=1:length(n.neur.c[k])
                n.extra[j].v+=fetch_extra(getfield(n.neur,k),l,j)
            end
        end
    end
    
    for j=1:length(n.intra)
        @inbounds n.intra[j].v=fetch_intra(getfield(n.neur,n.intra[j].mtype),n.intra[j].mtype,n.neur.i[j])   
    end 

    nothing  
end

function init!(n::NetworkS)

    @inbounds initialcon!(n.neur)

    #set up flags
    if length(n.extra)==0
        n.helper.flags[1]=false
    else
        n.helper.flags[1]=true
    end

    if length(n.intra)==0
        n.helper.flags[2]=false
    else
        n.helper.flags[2]=true
    end

    if length(n.stim)==0
        n.helper.flags[3]=false
    else
        n.helper.flags[3]=true
    end
end

init!(n::NetworkP)= @inbounds initialcon!(n.neur,0)

function main{T<:Neuron}(n::Array{T,1})

    @inbounds for i=1:length(n)
        main(n[i])
    end
    nothing
end

function main{T<:Puddle}(p::Array{T,1},j::Int64)

    @inbounds for i=1:length(p)
        main(p[i],j)
    end
    nothing
end

function main(p::Puddle,i::Int64)

    for j=1:length(p.h.s)
        @inbounds p.n[p.h.s[j].neur].rhs[p.h.s[j].node]+=p.h.s[j].Is[i]
    end
    
    main(p.n)

    for j=1:length(p.h.e)
        for k=1:length(p.n)
            @inbounds p.h.e[j].v[i]+=a_mult_b(p.h.e[j].coeffs[k],p.n[k])
        end
    end

    for j=1:length(p.h.i)
        @inbounds p.h.i[j].v[i]=p.n[p.h.i[j].neur].v[p.h.i[j].node]
    end
end

function initialcon!{T<:Neuron}(n::Array{T,1})

    @inbounds for i=1:length(n)
        initialcon!(n[i])
    end
    nothing
end

function initialcon!{T<:Puddle}(p::Array{T,1},i::Int64)

    @inbounds for i=1:length(p)
        initialcon!(p[i],i)
    end
    nothing
end

function initialcon!(p::Puddle,i::Int64)
    initialcon!(p.n)
end

function a_mult_b(x::Extra_coeffs,n::Neuron)
    c=0.0
    for i=1:length(x.c)
        @inbounds c+=x.c[i]*n.i_vm[x.inds[i]]
    end
    c
end

function neuron_ind(x::Int64,y::Array{UnitRange{Int64},1})

    ind=0
    newx=0
    mysum=0

    for i in y
    
        if (x<=i[end])&&(x>=i[1])
            newx=x-mysum
            ind+=1
            break
        end
    
        mysum+=length(i[1])
        ind+=1
    end

    (ind,newx)

end

function get_dims(dims)

    y=Array(UnitRange{Int64},0)

    for i in dims
        push!(y,i[1])
    end
    y
end

function add_intra(p::Int64,neur::Int64,node::Int64,t::Int64,n::DArray)

    remotecall_fetch(((x,neur,node,t)->(push!(localpart(x)[1].h.i,(Intracellular(1,neur,node,zeros(Float64,t))));length(localpart(x)[1].h.i))),p+1,n,neur,node,t)

end

function add_stim(p::Int64,neur::Int64,node::Int64,s::Array{Float64,1},n::DArray)

    remotecall_fetch(((x,neur,node,t)->(push!(localpart(x)[1].h.s,(Stim(t,1,neur,node,0.0,0.0)));length(localpart(x)[1].h.s))),p+1,n,neur,node,s)

end

function fetch_intra(nd::DArray,p::Int64,ind::Int64)
    remotecall_fetch(((n,j)->localpart(n)[1].h.i[j].v),p+1,nd,ind)
end

function add_extra(n::DArray,e::Extracellular)

    mycoeffs=Array(Extra_coeffs,0)
    
    for p in workers()
        append!(mycoeffs,add_extra(n,e,p))
    end

    mycoeffs  
end

function add_extra(n::DArray,e::Extracellular,p::Int64)
    remotecall_fetch(((x,y)->(c=extracellular(localpart(x)[1].n,y);push!(localpart(x)[1].h.e,typeof(e)(e.xyz,c,zeros(Float64,length(e.v))));c)),p,n,e)
end

function extracellular{T<:Neuron}(n::Array{T,1},e::Extracellular)

    mycoeffs=Array(Extra_coeffs,length(n))
    
    for i=1:length(n)
        mycoeffs[i]=extracellular(e,n[i],0.3)
    end

    mycoeffs   
end

function fetch_extra(nd::DArray,p::Int64,ind::Int64)
    remotecall_fetch(((n,j)->localpart(n)[1].h.e[j].v),p+1,nd,ind)
end
