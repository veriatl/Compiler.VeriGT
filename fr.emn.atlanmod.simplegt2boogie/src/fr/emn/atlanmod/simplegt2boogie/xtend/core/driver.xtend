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

class driver {

	def static void main(String[] args) {
		new driver().generate("model/Pacman.simplegt")
		println("finished")
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

	def generate(String file) {
		doEMFSetup
		val rs = new ResourceSetImpl
		val resource = rs.getResource(URI.createURI(file), true)

		for (content : resource.contents) {
			println(generateModule(content))
		}
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
			«genModuleElement(e)»
		«ENDFOR»
	'''

	// dispatcher
	def dispatch genModuleElement(ModuleElement element) '''
		_PlaceHolder
	'''

	// simplegt rule
	def dispatch genModuleElement(Rule r) '''
		procedure «r.name»_match(«FOR i : r.input.elements SEPARATOR ", "»«i.varName»: ref«ENDFOR») returns (b: bool);
		// input are allocated

		// semantic matching
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
	
	/* Code generation ends */
}
