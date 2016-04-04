package fr.emn.atlanmod.simplegt2boogie.xtend.core

import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EPackage
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl
import org.eclipse.emf.ecore.resource.Resource
import org.eclipselabs.simplegt.SimplegtFactory
import org.eclipselabs.simpleocl.*
import org.eclipse.emf.ecore.EObject
import org.eclipselabs.simplegt.SimplegtPackage
import org.eclipselabs.simpleocl.SimpleoclPackage
import org.eclipse.emf.ecore.xmi.impl.EcoreResourceFactoryImpl
import org.eclipse.m2m.atl.emftvm.EmftvmFactory
import org.eclipselabs.simplegt.resource.simplegt.mopp.SimplegtResource
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipselabs.simplegt.resource.simplegt.mopp.SimplegtResourceFactory
import org.eclipse.m2m.atl.emftvm.Model
import org.eclipselabs.simpleocl.ModuleElement
import org.eclipselabs.simplegt.Rule
import java.util.ArrayList
import java.util.HashMap
import org.eclipselabs.simpleocl.OclExpression
import org.eclipselabs.simpleocl.VariableExp
import org.eclipse.emf.common.util.EList
import org.eclipselabs.simplegt.InputElement
import org.eclipse.emf.ecore.EClassifier
import org.eclipse.emf.ecore.EClass
import org.eclipselabs.simplegt.OutputElement
import org.eclipselabs.simpleocl.OclType
import java.util.Set
import java.util.HashSet

// todo
//- nac elements
class driver {
	
	var fMap = new HashMap<String, String>
	
	def static void main(String[] args) {
		new driver().generate("model/Pacman.simplegt", "model/Pacman.ecore")
		println("finished")
	}



	def generate(String file, String mm) {
		doEMFSetup
		val rs = new ResourceSetImpl
		val resource = rs.getResource(URI.createURI(file), true)
		var srcmm = rs.getResource(URI.createURI(mm), true)
		
		fMap = getsfInfo(srcmm)
		
		for (content : resource.contents) {
			println(generateModule(content))
		}
	}
	
	def getsfInfo(Resource resource) {
		var r = new HashMap<String, String>
		for (content : resource.contents) {
			if(content instanceof EPackage){
				for(c : content.getEClassifiers){
					if(c instanceof EClass){
						for(sf : c.getEStructuralFeatures()){
							var nm = String.format("%s$%s.%s", content.name, c.name, sf.name)
							if(sf.getEType.getName == "EInt"){
								r.put(nm, "int")
							}else if(sf.getEType.getName == "EString"){
								r.put(nm, "string")
							}else if(sf.getEType.getName == "EBoolean"){
								r.put(nm, "bool")	
							}else{
								r.put(nm, "ref")
							}						
						}
					}
				}
			}
		}
		return r
	}
	
	def isPrimitive(String s) {
		if(s == "int" || s == "string" || s=="bool")
			true
		else
			false
	}
	
	
	def doEMFSetup() {
		// load metamodels
		EPackage$Registry.INSTANCE.put("http://eclipselabs.org/simplegt/2013/SimpleOCL", SimpleoclPackage.eINSTANCE)
		EPackage$Registry.INSTANCE.put("http://eclipselabs.org/simplegt/2013/SimpleGT", SimplegtPackage.eINSTANCE)

		// register resource processors
		Resource$Factory.Registry.INSTANCE.extensionToFactoryMap.put("xmi", new XMIResourceFactoryImpl);
		Resource$Factory.Registry.INSTANCE.extensionToFactoryMap.put("simplegt", new SimplegtResourceFactory());
		Resource$Factory.Registry.INSTANCE.extensionToFactoryMap.put("ecore", new EcoreResourceFactoryImpl());
	}

	/* Code generation starts */
	// dispatcher
	def dispatch generateModule(EObject it) '''
		_PlaceHolder
	'''

	// module
	def dispatch generateModule(Module mod) '''
		
		Module: «mod.name» 
		
		«FOR e : mod.elements»
			===
			«genModuleElement_apply(e)»
		«ENDFOR»
	'''

	// dispatcher
	def dispatch genModuleElement_apply(ModuleElement element) '''
		_PlaceHolder
	'''

	def genOutputElementType(OutputElement e){
		return getModel(e.type)+"$"+e.type.name
	}

	def genIutputElementType(InputElement e){
		return getModel(e.type)+"$"+e.type.name
	}
	
	// simplegt rule apply
	def dispatch genModuleElement_apply(Rule r) '''
		«var addElems = listDifference1(r.output.elements, r.input.elements)»
		«var delElems = listDifference2(r.output.elements, r.input.elements)»
		«var ib = new HashMap<String, OclExpression>»	
		«var ob = new HashMap<String, OclExpression>»
		«var frame = new HashMap<String, Set<String>>»
		procedure «r.name»_apply(«FOR i : r.input.elements SEPARATOR ", "»«i.varName»: ref«ENDFOR»«IF addElems.size()!=0», «FOR e : addElems SEPARATOR ", "»«e.varName»: ref«ENDFOR»«ENDIF» ) returns ();
		requires $Well_form(«getHeapName»);
		// syntactic matching
		requires Seq#Contains(findPatterns_«r.name»($srcHeap), «genInputSequence(r.input.elements)»);
		// semantic matching
		«FOR i : r.input.elements»
			«FOR b : i.bindings»
				«IF isPrimitive(fMap.get(genIutputElementType(i)+"."+b.property))»
					requires read(«getHeapName», «i.varName», «genIutputElementType(i)».«b.property») == «printOCL(b.expr, false)»;
				«ENDIF»
			«ENDFOR»
		«ENDFOR»
		// nac
		«FOR n : r.nac»
				
		«ENDFOR»
		modifies «getHeapName»;
		ensures $Well_form(«getHeapName»);
		«««ADD ELEM»»»
		«FOR e : addElems»
		ensures «e.varName»!=null && read(«getHeapName», «e.varName», alloc) && dtype(«e.varName») <: «genOutputElementType(e)»;
		«IF frame.containsKey(e.varName)»
		«{frame.get(e.varName).add("alloc");""}»
		«ELSE»
		«{frame.put(e.varName, new HashSet<String>());""}»
		«{frame.get(e.varName).add("alloc");""}»
		«ENDIF»
		«ENDFOR»
		«««DEL ELEM»»»
		«FOR e : delElems»
		ensures ! read(«getHeapName», «e.varName», alloc);
		«IF frame.containsKey(e.varName)»
		«{frame.get(e.varName).add("alloc");""}»
		«ELSE»
		«{frame.put(e.varName, new HashSet<String>());""}»
		«{frame.get(e.varName).add("alloc");""}»
		«ENDIF»
		«ENDFOR»		
		«FOR i : r.input.elements»
			«IF i.bindings != null»
				«FOR b : i.bindings»
					«ib.put(i.varName+"_sep_"+genIutputElementType(i)+"."+b.property, b.expr)»
				«ENDFOR»
			«ENDIF»
		«ENDFOR»
		«FOR o : r.output.elements»
			«IF o.bindings != null»
				«FOR b : o.bindings»
					«ob.put(o.varName+"_sep_"+genOutputElementType(o)+"."+b.property, b.expr)»
				«ENDFOR»
			«ENDIF»
		«ENDFOR»		
		«FOR k : ib.keySet»
			«var obj = k.split("_sep_").get(0)»
			«var field = k.split("_sep_").get(1)»
			«IF ob.keySet.contains(k)»
				«««Preserved»»»
				«IF oclEqualCheck(ib.get(k), ob.get(k))» 	
				«««UPDATE»»»
				«ELSE»
				ensures read(«getHeapName», «obj», «field») == «printOCL(ob.get(k), true)»;
				«IF frame.containsKey(obj)»
					«{frame.get(obj).add(field);""}»
				«ELSE»
					«{frame.put(obj, new HashSet<String>());""}»
					«{frame.get(obj).add(field);""}»
				«ENDIF»
				«ENDIF»
			«««REMOVE»»»
			«ELSE»
			ensures read(«getHeapName», «obj», «field») == «printDefaultVal(field)»»;
			ensures !isset(«getSetTableName», «obj», «field»);
			«IF frame.containsKey(obj)»
				«{frame.get(obj).add(field);""}»
			«ELSE»
				«{frame.put(obj, new HashSet<String>());""}»
				«{frame.get(obj).add(field);""}»
			«ENDIF»
			«ENDIF»
		«ENDFOR»
		«FOR k : ob.keySet»
			«IF !ib.keySet.contains(k)»«««ADD»»»
			«var obj = k.split("_sep_").get(0)»
			«var field = k.split("_sep_").get(1)»
			ensures read(«getHeapName», «obj», «field») == «printOCL(ob.get(k), true)»;
			«IF frame.containsKey(obj)»
				«{frame.get(obj).add(field);""}»
			«ELSE»
				«{frame.put(obj, new HashSet<String>());""}»
				«{frame.get(obj).add(field);""}»
			«ENDIF»
			«ENDIF»
		«ENDFOR»
		ensures (forall<alpha> o:ref,f:Field alpha::
		  o!=null && read(old($srcHeap),o,alloc) ==> 
		  (read($srcHeap,o,f)==read(old($srcHeap),o,f)) ||
		  «IF frame.keySet.size!=0»
		  	«FOR o:frame.keySet SEPARATOR "||"»
		  	(o == «o» && («FOR f:frame.get(o) SEPARATOR "||"» f == «f»«ENDFOR»))
		  	«ENDFOR»
		  «ENDIF»
		);
	'''
	
	def printDefaultVal(String s) {
		var v = fMap.get(s)

		if(v == "int"){
			return "0"
		}else if(v == "string"){
			return "Seq#Empty()"
		}else if(v == "bool"){
			return "false"
		}else{
			return "null"
		}
	}
	
	def getModel(OclType type) {
		if(type instanceof OclModelElement){
			return type.model.name
		}else{
			return "unknown"
		}
	}
	
	def listDifference1(EList<OutputElement> outs, EList<InputElement> ins) {
		var r = new ArrayList<OutputElement>();
		for(o : outs){
			var add = true;
			for(i : ins){
				if(o.varName == i.varName){
					add = false;
				}
			}
			
			if(add){
				r.add(o)
			}
		}
		return r
	}
	

	def listDifference2(EList<OutputElement> outs, EList<InputElement> ins) {
		var r = new ArrayList<InputElement>();
		for(i : ins){
			var del = true;
			for(o : outs){
				if(o.varName == i.varName){
					del = false;
				}
			}
			
			if(del){
				r.add(i)
			}
		}
		return r
	}
	
	
	def genInputSequence(EList<InputElement> list) {
		var i = 0
		var r = ""
		for(e : list){
			if(i == 0){
				r += "Seq#Singleton("+e.varName+")";
			}else{
				r = "Seq#Build("+ r + ","+ e.varName +")";
			}
			i++
		}
		r
	}
	
	def getHeapName() {
		"$srcHeap"
	}
	
	def getSetTableName(){
		"$acc"
	}
	
	def oclEqualCheck(OclExpression expr1, OclExpression expr2) {
		if(expr1.eClass().getName != expr2.eClass().getName){
			false
		}else{
			switch(expr1.eClass().getName){
				case "VariableExp": { if( (expr1 as VariableExp).getReferredVariable.getVarName == (expr2 as VariableExp).getReferredVariable.getVarName ) {true} else {false} }
				case "IntegerExp": {if((expr1 as IntegerExp).getIntegerSymbol == (expr2 as IntegerExp).getIntegerSymbol) true else false}
				default: false
			}
		}
	}
	
	def dispatch printOCL(OclExpression expr, boolean old) ''''''
	
	def dispatch printOCL(IntegerExp expr, boolean old) '''«expr.integerSymbol»'''
	
	def dispatch printOCL(VariableExp expr, boolean old) '''«expr.referredVariable.varName»'''
	
	def dispatch printOCL(PropertyCallExp expr, boolean old) '''
	«FOR call : expr.calls»«IF expr.source instanceof VariableExp && call instanceof NavigationOrAttributeCall» read(«IF old»old(«getHeapName»)«ELSE»«getHeapName»«ENDIF», «(expr.source as VariableExp).referredVariable.varName», «(expr.source as VariableExp).referredVariable.type.name».«(call as NavigationOrAttributeCall).name»)«ENDIF»	«ENDFOR»'''
	
	def dispatch printOCL(AddOpCallExp expr, boolean old)''' «printOCL(expr.source, true)»+«printOCL(expr.argument, true)» '''
	
	
	
	/* Code generation ends */
}
