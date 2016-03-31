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
							var nm = String.format("%s.%s", c.name, sf.name)
							if(isPrimitive(sf.getEType.getName)){
								r.put(nm, "primitive")
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
		if(s == "EInt" || s == "EString" || s=="EBoolean")
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

	// simplegt rule
	def dispatch genModuleElement_apply(Rule r) '''
		procedure «r.name»_apply(«FOR i : r.input.elements SEPARATOR ", "»«i.varName»: ref«ENDFOR») returns (b: bool);
	 	requires $Well_form(«getHeapName»);
	 	// syntactic matching
		requires Seq#Contains(findPatterns_«r.name»($srcHeap), «genInputSequence(r.input.elements)»);
		// semantic matching
		«FOR i : r.input.elements»
			«FOR b : i.bindings»
				«IF fMap.get(i.type.name+"."+b.property) == "primitive"»
					requires read(«getHeapName», «i.varName», «i.type.name».«b.property») == «printOCL(b.expr)»;
				«ENDIF»
			«ENDFOR»
		«ENDFOR»
		// nac
		«FOR n : r.nac»
				
		«ENDFOR»
		modifies «getHeapName»;
		ensures $Well_form(«getHeapName»);
		«FOR i : r.input.elements»
			«var isDel = 0»
			«FOR o : r.output.elements»
				«IF i.varName == o.varName»
					«{isDel = 1; ""}»
				«ENDIF»
			«ENDFOR»
			
			«IF isDel == 0»
				«i.varName»: Delete
			«ELSE»
				«i.varName»: Preserve
			«ENDIF»
		«ENDFOR»
		
		«FOR o : r.output.elements»
			«var isAdd = 1»
			«FOR i : r.input.elements»
				«IF i.varName == o.varName»
					«{isAdd = 0; ""}»
				«ENDIF»
			«ENDFOR»
			«IF isAdd == 1»
				«o.varName»: Add
			«ENDIF»
		«ENDFOR»	
		
		«var ib = new HashMap<String, OclExpression>»	
		«var ob = new HashMap<String, OclExpression>»
		
		«FOR i : r.input.elements»
			«IF i.bindings != null»
				«FOR b : i.bindings»
					«ib.put(i.varName+"."+i.type.name+"."+b.property, b.expr)»
				«ENDFOR»
			«ENDIF»
		«ENDFOR»
	
		«FOR o : r.output.elements»
			«IF o.bindings != null»
				«FOR b : o.bindings»
					«ob.put(o.varName+"."+o.type.name+"."+b.property, b.expr)»
				«ENDFOR»
			«ENDIF»
		«ENDFOR»
		
		
		«FOR k : ib.keySet»
			«IF ob.keySet.contains(k)»
				«IF oclEqualCheck(ib.get(k), ob.get(k))»
					«k»: Preserved
				«ELSE»
					«k»: UPDATE
				«ENDIF»
			«ELSE»
				«k»: DEL
			«ENDIF»
		«ENDFOR»
		
		«FOR k : ob.keySet»
			«IF !ib.keySet.contains(k)»
				«k»: ADD
			«ENDIF»
		«ENDFOR»
	'''
	

	
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
	
	def oclEqualCheck(OclExpression expr1, OclExpression expr2) {
		if(expr1.eClass().getName != expr2.eClass().getName){
			false
		}else{
			switch(expr1.eClass().getName){
				case "VariableExp": { if( (expr1 as VariableExp).getReferredVariable.getVarName == (expr2 as VariableExp).getReferredVariable.getVarName ) {true} else {false} }
				default: false
			}
		}
	}
	
	def dispatch printOCL(OclExpression expr) '''
	'''
	
	def dispatch printOCL(IntegerExp expr) '''«expr.integerSymbol»'''
	
	def dispatch printOCL(PropertyCallExp expr) '''
	«FOR call : expr.calls»
		«IF expr.source instanceof VariableExp && call instanceof NavigationOrAttributeCall»
			read(«getHeapName», «(expr.source as VariableExp).referredVariable.varName», «(expr.source as VariableExp).referredVariable.type.name».«(call as NavigationOrAttributeCall).name»)	
		«ENDIF»	
	«ENDFOR»
	'''
	/* Code generation ends */
}
